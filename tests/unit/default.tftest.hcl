# Unit tests — uses mock provider, no credentials required.

mock_provider "powerplatform" {}

run "validates_name_variable" {
  command = plan

  variables {
    name     = "test-module"
    location = "unitedstates"
  }

  assert {
    condition     = var.name == "test-module"
    error_message = "Variable 'name' was not set correctly."
  }
}

run "validates_location_variable" {
  command = plan

  variables {
    name     = "test-module"
    location = "europe"
  }

  assert {
    condition     = var.location == "europe"
    error_message = "Variable 'location' was not set correctly."
  }
}

run "outputs_name_value" {
  command = plan

  variables {
    name     = "test-output"
    location = "unitedstates"
  }

  assert {
    condition     = output.name == "test-output"
    error_message = "Output 'name' should match the input variable."
  }
}

run "rejects_empty_name" {
  command = plan

  variables {
    name     = ""
    location = "unitedstates"
  }

  expect_failures = [
    var.name,
  ]
}

run "rejects_invalid_location" {
  command = plan

  variables {
    name     = "test-module"
    location = "invalid-location"
  }

  expect_failures = [
    var.location,
  ]
}

run "accepts_optional_tags" {
  command = plan

  variables {
    name     = "test-module"
    location = "unitedstates"
    tags = {
      environment = "test"
    }
  }

  assert {
    condition     = var.tags["environment"] == "test"
    error_message = "Tags should be accepted as optional input."
  }
}
