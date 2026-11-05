# The domain module on its own: group names and zone tagging.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

variables {
  name         = "w01"
  zone         = "w01"
  vcenter_name = "w01-vc01"
  hosts        = ["203.0.113.0/28"]
}

run "minimal_domain" {
  module {
    source = "./modules/domain"
  }

  assert {
    condition     = nsxt_policy_group.vc.nsx_id == "W01_VC"
    error_message = "Unexpected vCenter group name."
  }
  assert {
    condition     = one(one(nsxt_policy_group.vc.criteria).condition).operator == "EQUALS" && one(one(nsxt_policy_group.vc.criteria).condition).value == "w01-vc01"
    error_message = "The vCenter group should match the exact VM name."
  }
  assert {
    condition     = keys(nsxt_policy_group.ip) == ["hosts"] && nsxt_policy_group.ip["hosts"].nsx_id == "W01_HOSTS"
    error_message = "Only the hosts IP group should exist when the other lists are empty."
  }
  assert {
    condition     = output.group_paths.sup == null && output.group_paths.edge == null
    error_message = "Unconfigured groups should be null."
  }
}

run "full_domain_in_shared_zone" {
  module {
    source = "./modules/domain"
  }

  variables {
    name                = "w02"
    zone                = "w01"
    vcenter_name        = "w02-vc01"
    edges               = ["203.0.113.16/28"]
    supervisors         = ["203.0.113.64/28"]
    avi_service_engines = ["203.0.113.96/28"]
  }

  assert {
    condition     = toset([for g in nsxt_policy_group.ip : g.nsx_id]) == toset(["W02_HOSTS", "W02_EDGE", "W02_SUP", "W02_AVI_SE"])
    error_message = "All IP groups should exist, named after the domain."
  }
  assert {
    condition     = alltrue([for k, g in nsxt_policy_group.ip : one(g.tag).scope == "w01" && one(g.tag).tag == "w02_${k}"])
    error_message = "IP groups should carry the zone as tag scope and the domain in the tag."
  }
}
