# The nsx-manager-cluster module on its own: shared edges and SSP grouping.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

variables {
  name           = "w01"
  vm_name_prefix = "w01-nsx01"
}

run "minimal_cluster" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  assert {
    condition     = keys(nsxt_policy_group.named) == ["nsx"] && length(nsxt_policy_group.ip) == 0
    error_message = "Only the NSX Manager group should exist."
  }
  assert {
    condition     = output.group_paths.ssp == null && !output.ssp_dfw
    error_message = "Unconfigured groups should be null."
  }
}

run "ssp_in_management_domain" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  variables {
    ssp = { node_prefix = "w01-ssp-", service_pool = ["203.0.113.32/28"] }
  }

  assert {
    condition     = nsxt_policy_group.named["ssp"].nsx_id == "W01_SSP" && !contains(keys(nsxt_policy_group.ip), "ssp") && output.ssp_dfw
    error_message = "An SSP in the management domain should be grouped by VM name and DFW-protected."
  }
  assert {
    condition     = one(nsxt_policy_group.ip["ssp_svc"].tag).scope == "w01"
    error_message = "The SSP Service IP Pool should be tagged with the zone."
  }
}

run "display_name_differs_from_id" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  variables {
    display_name = "W01_W02"
    ssp          = { node_pool = ["203.0.113.64/28"], service_pool = ["203.0.113.32/28"] }

    ssp_in_management_domain = false
  }

  assert {
    condition     = nsxt_policy_group.named["nsx"].nsx_id == "W01_NSX" && nsxt_policy_group.named["nsx"].display_name == "W01_W02_NSX"
    error_message = "IDs should use the cluster key and display names the label."
  }
  assert {
    condition     = nsxt_policy_group.ip["ssp_svc"].nsx_id == "W01_SSP_SVC" && nsxt_policy_group.ip["ssp_svc"].display_name == "W01_W02_SSP_SVC"
    error_message = "IP groups should split ID and display name the same way."
  }
}

run "ssp_in_workload_domain" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  variables {
    ssp                      = { node_pool = ["203.0.113.64/28"], service_pool = ["203.0.113.32/28"] }
    ssp_in_management_domain = false
  }

  assert {
    condition     = nsxt_policy_group.ip["ssp"].nsx_id == "W01_SSP" && nsxt_policy_group.ip["ssp"].group_type == "IPAddress" && !contains(keys(nsxt_policy_group.named), "ssp")
    error_message = "An SSP in a workload domain should be grouped by its Node IP Pool."
  }
  assert {
    condition     = !output.ssp_dfw && output.group_paths.ssp != null
    error_message = "An SSP in a workload domain is not DFW-protected but still has a group."
  }
}
