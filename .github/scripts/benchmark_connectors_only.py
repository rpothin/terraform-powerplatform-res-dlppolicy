#!/usr/bin/env python3
"""Run a sanitized, plan-only v0.1.4 versus current-branch benchmark."""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


BASELINE_REF = "v0.1.4"
PROVIDER_VERSION = "4.2.1"
POLICY_ID_PATTERN = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)
UUID_PATTERN = re.compile(
    r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"
)
TRACE_VERTEX_PATTERN = re.compile(
    r'^(?P<timestamp>\S+)\s+\[TRACE\].*vertex "(?P<address>[^"]+)": '
    r"(?P<event>starting visit|visit complete)"
)
HTTP_ERROR_STATUS_PATTERN = re.compile(
    r"(?i)\b(?:HTTP/[\d.]+|HTTP(?: status)?|status(?: code)?|statuscode)\s*[:=]?\s*([45]\d{2})\b"
)


def fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    raise SystemExit(1)


def run_quiet(command: list[str], cwd: Path, stage: str) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode:
        fail(f"{stage} failed (exit code {result.returncode}); raw command output was suppressed.")
    return result


def archive_ref(workspace: Path, ref: str, destination: Path) -> None:
    archive = subprocess.Popen(
        ["git", "archive", "--format=tar", ref],
        cwd=workspace,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    assert archive.stdout is not None
    extraction = subprocess.run(
        ["tar", "-xf", "-", "-C", str(destination)],
        stdin=archive.stdout,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    archive.stdout.close()
    archive.wait()
    if archive.returncode or extraction.returncode:
        fail(
            f"Could not prepare benchmark source {ref} "
            f"(git archive exit {archive.returncode}, tar exit {extraction.returncode})."
        )


def pin_provider(module_dir: Path) -> None:
    config = module_dir / "terraform.tf"
    source = config.read_text(encoding="utf-8")
    pinned, replacements = re.subn(
        r'version\s*=\s*"~>\s*4\.0"',
        f'version = "= {PROVIDER_VERSION}"',
        source,
    )
    if replacements != 1:
        fail(f"Expected one provider constraint in {config.name}; found {replacements}.")
    config.write_text(pinned, encoding="utf-8")


def parse_timestamp(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def safe_diagnostic(value: str) -> str:
    value = re.sub(r"https?://\S+", "<redacted-url>", value)
    value = UUID_PATTERN.sub("<redacted-id>", value)
    value = re.sub(r"(?i)\bBearer\s+\S+", "Bearer <redacted>", value)
    return value.strip(" │\t")


def run_plan(
    module_dir: Path,
    plan_path: Path,
    trace_address: str,
    base_env: dict[str, str],
) -> tuple[float, float]:
    command = [
        "terraform",
        "plan",
        "-input=false",
        "-no-color",
        f"-out={plan_path}",
    ]

    env = base_env.copy()
    env["TF_LOG"] = "TRACE"
    start_time = time.monotonic()
    target_start: dt.datetime | None = None
    target_durations: list[float] = []
    diagnostics: list[str] = []
    http_error_statuses: set[str] = set()
    process = subprocess.Popen(
        command,
        cwd=module_dir,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    assert process.stdout is not None
    for line in process.stdout:
        http_status = HTTP_ERROR_STATUS_PATTERN.search(line)
        if http_status is not None:
            http_error_statuses.add(http_status.group(1))
        diagnostic = re.search(r"(?:^|\s)│?\s*Error:\s*(.*)", line)
        if diagnostic is not None:
            diagnostics.append(safe_diagnostic(diagnostic.group(1)))
        match = TRACE_VERTEX_PATTERN.match(line)
        if match is None or match.group("address") != trace_address:
            continue
        timestamp = parse_timestamp(match.group("timestamp"))
        if match.group("event") == "starting visit":
            if target_start is not None:
                fail(f"Terraform trace contained overlapping visits for {trace_address}.")
            target_start = timestamp
        elif target_start is not None:
            target_durations.append((timestamp - target_start).total_seconds())
            target_start = None

    return_code = process.wait()
    elapsed = time.monotonic() - start_time
    if return_code:
        summary = diagnostics[0] if diagnostics else "no sanitized Terraform diagnostic was available"
        if http_error_statuses:
            statuses = ", ".join(sorted(http_error_statuses))
            summary = f"{summary} (observed HTTP status: {statuses})"
        fail(
            f"Terraform plan failed in {module_dir.name} (exit code {return_code}): "
            f"{summary}. Raw logs were suppressed."
        )
    if target_start is not None:
        fail(f"Terraform trace ended during a visit to {trace_address}.")
    if len(target_durations) != 1:
        fail(
            f"Expected one {trace_address} data-source visit in the Terraform trace; "
            f"found {len(target_durations)}."
        )
    return elapsed, target_durations[0]


def show_plan(module_dir: Path, plan_path: Path) -> dict[str, Any]:
    result = run_quiet(
        ["terraform", "show", "-json", str(plan_path)],
        cwd=module_dir,
        stage="Reading sanitized plan values",
    )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        fail("Terraform returned an unreadable plan JSON document.")


def resources(plan: dict[str, Any]) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []

    def visit(module: dict[str, Any]) -> None:
        found.extend(module.get("resources", []))
        for child in module.get("child_modules", []):
            visit(child)

    root = plan.get("planned_values", {}).get("root_module")
    if root:
        visit(root)
    return found


def find_resource(plan: dict[str, Any], mode: str, resource_type: str, name: str) -> dict[str, Any]:
    matches = [
        item
        for item in resources(plan)
        if item.get("mode") == mode
        and item.get("type") == resource_type
        and item.get("name") == name
    ]
    if len(matches) != 1:
        fail(f"Expected one {mode} {resource_type}.{name} in the plan; found {len(matches)}.")
    return matches[0]


def policy_count(plan: dict[str, Any]) -> int:
    datasource = find_resource(
        plan,
        "data",
        "powerplatform_data_loss_prevention_policies",
        "current",
    )
    policies = datasource.get("values", {}).get("policies")
    if not isinstance(policies, list):
        fail("The baseline policy data source did not return a policy list.")
    return len(policies)


def policy_resource_change(plan: dict[str, Any]) -> dict[str, Any]:
    matches = [
        change
        for change in plan.get("resource_changes", [])
        if change.get("mode") == "managed"
        and change.get("type") == "powerplatform_data_loss_prevention_policy"
        and change.get("name") == "this"
    ]
    if len(matches) != 1:
        fail(f"Expected one managed DLP policy change; found {len(matches)}.")
    change = matches[0].get("change", {})
    after = change.get("after")
    if after is None:
        fail("The planned DLP policy configuration was unavailable for parity comparison.")
    return {"actions": change.get("actions", []), "after": after}


def minutes(seconds: float) -> str:
    return f"{seconds / 60:.2f} min"


def main() -> None:
    workspace = Path(os.environ.get("GITHUB_WORKSPACE", Path.cwd())).resolve()
    candidate_ref = os.environ.get("GITHUB_SHA")
    policy_id = os.environ.get("INTEGRATION_TEST_EXISTING_POLICY_ID", "")
    if not candidate_ref:
        fail("GITHUB_SHA is required to select the benchmark candidate.")
    if not POLICY_ID_PATTERN.fullmatch(policy_id):
        fail("INTEGRATION_TEST_EXISTING_POLICY_ID must be configured as a UUID repository variable.")
    if not os.environ.get("POWER_PLATFORM_TENANT_ID") or not os.environ.get("POWER_PLATFORM_CLIENT_ID"):
        fail("The Power Platform OIDC repository secrets are not configured.")

    with tempfile.TemporaryDirectory(prefix="dlp-policy-benchmark-") as temporary_root:
        temp = Path(temporary_root)
        baseline_dir = temp / "baseline"
        candidate_dir = temp / "candidate"
        baseline_dir.mkdir()
        candidate_dir.mkdir()
        archive_ref(workspace, BASELINE_REF, baseline_dir)
        archive_ref(workspace, candidate_ref, candidate_dir)
        pin_provider(baseline_dir)
        pin_provider(candidate_dir)

        env = os.environ.copy()
        env["POWER_PLATFORM_USE_OIDC"] = "true"
        env["TF_VAR_display_name"] = "tftest-connectors-only-benchmark"
        env["TF_VAR_environment_type"] = "OnlyEnvironments"
        env["TF_VAR_management_mode"] = "connectors_only"
        env["TF_VAR_existing_policy_id"] = policy_id

        for label, module_dir in (("baseline", baseline_dir), ("candidate", candidate_dir)):
            result = subprocess.run(
                ["terraform", "init", "-backend=false", "-input=false"],
                cwd=module_dir,
                env=env,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            if result.returncode:
                fail(f"Terraform initialization failed for {label} (exit code {result.returncode}).")

        baseline_policy_address = "data.powerplatform_data_loss_prevention_policies.current[0]"
        candidate_policy_address = "data.powerplatform_rest_query.live_policy[0]"
        baseline_full_duration, baseline_lookup_duration = run_plan(
            baseline_dir,
            temp / "baseline-full.tfplan",
            baseline_policy_address,
            env,
        )
        candidate_full_duration, candidate_lookup_duration = run_plan(
            candidate_dir,
            temp / "candidate-full.tfplan",
            candidate_policy_address,
            env,
        )
        baseline_full_plan = show_plan(baseline_dir, temp / "baseline-full.tfplan")
        candidate_full_plan = show_plan(candidate_dir, temp / "candidate-full.tfplan")
        baseline_policy_total = policy_count(baseline_full_plan)

        baseline_policy = find_resource(
            baseline_full_plan,
            "managed",
            "powerplatform_data_loss_prevention_policy",
            "this",
        )
        candidate_policy = find_resource(
            candidate_full_plan,
            "managed",
            "powerplatform_data_loss_prevention_policy",
            "this",
        )
        baseline_environments = sorted(baseline_policy.get("values", {}).get("environments", []))
        candidate_environments = sorted(candidate_policy.get("values", {}).get("environments", []))
        environments_match = baseline_environments == candidate_environments

        baseline_catalog = find_resource(
            baseline_full_plan,
            "data",
            "powerplatform_connectors",
            "all",
        )
        candidate_catalog = find_resource(
            candidate_full_plan,
            "data",
            "powerplatform_connectors",
            "all",
        )
        catalog_environment_match = (
            baseline_catalog.get("values", {}).get("environment_id")
            == candidate_catalog.get("values", {}).get("environment_id")
        )
        resource_plan_match = (
            policy_resource_change(baseline_full_plan)
            == policy_resource_change(candidate_full_plan)
        )
        if not environments_match or not catalog_environment_match or not resource_plan_match:
            fail("The before/after plans differ in environments, connector catalog scope, or planned DLP resource configuration.")

        try:
            terraform_version = json.loads(
                subprocess.run(
                    ["terraform", "version", "-json"],
                    check=True,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                ).stdout
            )["terraform_version"]
        except (json.JSONDecodeError, KeyError):
            fail("Could not read the Terraform CLI version for the benchmark report.")
        report = "\n".join(
            [
                "## connectors_only before/after benchmark",
                "",
                f"- Baseline: `{BASELINE_REF}`; candidate commit: `{candidate_ref[:12]}`",
                f"- Terraform version: `{terraform_version}`",
                f"- Power Platform provider version: `{PROVIDER_VERSION}`",
                "- Execution: sequential, plan-only, no backend/state, identical isolated OIDC fixture and inputs.",
                "",
                "| Measurement | v0.1.4 | Candidate |",
                "|---|---:|---:|",
                f"| Target policy data-source read | {minutes(baseline_lookup_duration)} | {minutes(candidate_lookup_duration)} |",
                f"| Full plan | {minutes(baseline_full_duration)} | {minutes(candidate_full_duration)} |",
                "",
                f"| Logical policy API request pattern (provider {PROVIDER_VERSION}; retries excluded) | Result |",
                "|---|---|",
                f"| v0.1.4 | 1 tenant policy list + {baseline_policy_total} per-policy GETs |",
                "| Candidate | 1 GET `/providers/PowerPlatform.Governance/v2/policies/{policy-id}` |",
                "",
                f"- Planned environment membership: **MATCH** ({len(baseline_environments)} IDs; identifiers omitted).",
                "- Connector catalog `environment_id`: **MATCH** (identifier omitted).",
                "- Planned DLP resource actions and configuration JSON: **MATCH**.",
                "- Plans were never applied. Because no state backend is used, resource parity compares the planned resource configuration/actions between versions; it does not claim a no-op against a separately managed remote state.",
                "- The provider does not log successful HTTP request URLs; logical request counts/routes above are derived from its data-source implementation and the returned baseline policy count. Raw trace output was streamed and discarded.",
            ]
        )
        print(report)
        summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_file:
            with Path(summary_file).open("a", encoding="utf-8") as summary:
                summary.write(report + "\n")


if __name__ == "__main__":
    main()
