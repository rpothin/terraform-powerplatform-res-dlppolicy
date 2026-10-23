#!/usr/bin/env bash
set -euo pipefail

missing_policy_id="f57a0b7d-51b9-4f2c-8fa5-bb0f3f3f8b8a"
diagnostics_file="$(mktemp)"
trap 'rm -f "$diagnostics_file"' EXIT

if TF_VAR_display_name="tftest-missing-policy" \
  TF_VAR_environment_type="OnlyEnvironments" \
  TF_VAR_management_mode="connectors_only" \
  TF_VAR_existing_policy_id="$missing_policy_id" \
  terraform plan -input=false -no-color >"$diagnostics_file" 2>&1; then
  echo "::error::A nonexistent connectors_only policy unexpectedly produced a plan."
  exit 1
fi

if ! grep -Eiq '(^|[^[:alnum:]])404([^[:alnum:]]|$)|not[[:space:]_-]*found|does not exist' "$diagnostics_file"; then
  echo "::error::The nonexistent-policy plan failed, but its diagnostic did not identify a 404 or not-found response."
  exit 1
fi

echo "Verified the nonexistent connectors_only policy fails planning with a 404/not-found diagnostic."
