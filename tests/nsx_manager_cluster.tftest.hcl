# The nsx-manager-cluster module on its own: shared edge nodes.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

variables {
  name           = "w01"
  vm_name_prefix = "w01-nsx01"
  domains        = ["w01", "w02"]
}

run "without_shared_edges" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  assert {
    condition     = length(nsxt_policy_group.edge) == 0 && output.group_paths.edge == null
    error_message = "No edge group should exist without shared edges."
  }
}

run "with_shared_edges" {
  module {
    source = "./modules/nsx-manager-cluster"
  }

  variables {
    edges = ["203.0.113.48/29"]
  }

  assert {
    condition     = nsxt_policy_group.edge[0].nsx_id == "W01_NSX_EDGE" && nsxt_policy_group.edge[0].group_type == "IPAddress"
    error_message = "Unexpected shared edge group."
  }
  assert {
    condition     = toset([for t in nsxt_policy_group.edge[0].tag : t.scope]) == toset(["w01", "w02"])
    error_message = "The shared edge group should be tagged for every domain using the NSX Manager."
  }
}
