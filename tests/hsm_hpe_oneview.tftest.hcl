# The HPE OneView for VMware vCenter module on its own: appliance, OneView and iLO groups, and the
# rules it hands to the VCF Fleet Policy.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

override_resource {
  target = nsxt_policy_group.appliance["ov01"]
  values = { path = "/infra/domains/default/groups/HSM_OV01" }
}
override_resource {
  target = nsxt_policy_group.oneview["ov01"]
  values = { path = "/infra/domains/default/groups/HSM_OV01_OV" }
}
override_resource {
  target = nsxt_policy_group.ilo["ov01"]
  values = { path = "/infra/domains/default/groups/HSM_OV01_ILO" }
}

variables {
  service_paths = {
    "HTTPS"     = "/infra/services/HTTPS"
    "HTTP"      = "/infra/services/HTTP"
    "SSH"       = "/infra/services/SSH"
    "CIM-HTTPS" = "/infra/services/CIM-HTTPS"
    "TCP-5671"  = "/infra/services/TCP-5671"
    "TCP-3512"  = "/infra/services/TCP-3512"
  }
  bastion = "/infra/domains/default/groups/BASTION"
  hsms = {
    ov01 = {
      vm_name = "m01-hsm01"
      oneview = ["192.0.2.70"]
      ilo     = ["192.0.2.0/26"]
      vcs     = ["/infra/domains/default/groups/M01_VC", "/infra/domains/default/groups/W01_VC"]
      hosts   = ["/infra/domains/default/groups/M01_HOSTS"]
    }
    ov02 = {
      ips = ["198.51.100.70"]
      vcs = ["/infra/domains/default/groups/W05_VC"]
    }
    ov03 = {
      vm_name = "m01-hsm03"
      ips     = ["198.51.100.71"]
      vcs     = ["/infra/domains/default/groups/W05_VC"]
    }
  }
}

run "groups_and_rules" {
  module {
    source = "./modules/hsm-hpe-oneview"
  }

  assert {
    condition = (
      nsxt_policy_group.appliance["ov01"].nsx_id == "HSM_OV01" && length(nsxt_policy_group.appliance["ov01"].criteria) == 1 &&
      one(nsxt_policy_group.appliance["ov01"].criteria[0].condition).value == "m01-hsm01" &&
      nsxt_policy_group.oneview["ov01"].nsx_id == "HSM_OV01_OV" && nsxt_policy_group.ilo["ov01"].nsx_id == "HSM_OV01_ILO"
    )
    error_message = "A VM-specified appliance should get a VM-name group, plus OneView and iLO IP groups."
  }
  assert {
    condition = (
      length(nsxt_policy_group.appliance["ov02"].criteria) == 1 &&
      one(nsxt_policy_group.appliance["ov02"].criteria[0].ipaddress_expression).ip_addresses == toset(["198.51.100.70"]) &&
      length(nsxt_policy_group.appliance["ov03"].criteria) == 2 && nsxt_policy_group.appliance["ov03"].conjunction[0].operator == "OR"
    )
    error_message = "An appliance given by IP should get an IP criterion; with both, the group should match either."
  }
  assert {
    condition     = !contains(keys(nsxt_policy_group.oneview), "ov02") && !contains(keys(nsxt_policy_group.ilo), "ov02")
    error_message = "No OneView or iLO groups should be created when none are given."
  }
  assert {
    condition = jsonencode({ for r in output.rules : r.display_name => [r.source_groups, r.destination_groups, r.services, r.direction] if strcontains(r.display_name, "OV01") }) == jsonencode({
      "vCenters to HSM OV01"  = [["/infra/domains/default/groups/M01_VC", "/infra/domains/default/groups/W01_VC"], ["/infra/domains/default/groups/HSM_OV01"], ["/infra/services/HTTPS", "/infra/services/TCP-3512"], "IN_OUT"]
      "HSM OV01 to vCenters"  = [["/infra/domains/default/groups/HSM_OV01"], ["/infra/domains/default/groups/M01_VC", "/infra/domains/default/groups/W01_VC"], ["/infra/services/HTTPS"], "IN_OUT"]
      "HSM OV01 to OneView"   = [["/infra/domains/default/groups/HSM_OV01"], ["/infra/domains/default/groups/HSM_OV01_OV"], ["/infra/services/HTTPS", "/infra/services/TCP-5671"], "IN_OUT"]
      "HSM OV01 to iLOs"      = [["/infra/domains/default/groups/HSM_OV01"], ["/infra/domains/default/groups/HSM_OV01_ILO"], ["/infra/services/HTTP", "/infra/services/HTTPS"], "IN_OUT"]
      "iLOs to HSM OV01"      = [["/infra/domains/default/groups/HSM_OV01_ILO"], ["/infra/domains/default/groups/HSM_OV01"], ["/infra/services/HTTPS", "/infra/services/TCP-3512"], "IN"]
      "HSM OV01 to ESX hosts" = [["/infra/domains/default/groups/HSM_OV01"], ["/infra/domains/default/groups/M01_HOSTS"], ["/infra/services/HTTPS", "/infra/services/SSH", "/infra/services/CIM-HTTPS"], "IN_OUT"]
      "Bastion to HSM OV01"   = [["/infra/domains/default/groups/BASTION"], ["/infra/domains/default/groups/HSM_OV01"], ["/infra/services/TCP-3512"], "IN"]
    })
    error_message = "Unexpected OV01 rules: ${jsonencode([for r in output.rules : r if strcontains(r.display_name, "OV01")])}"
  }
  assert {
    condition     = toset(output.hsms["ov02"].rules) == toset(["vCenters to HSM OV02", "HSM OV02 to vCenters"])
    error_message = "An IP-only appliance should get just the two vCenter rules, which are enforced at the vCenters."
  }
  assert {
    condition     = toset(output.hsms["ov03"].rules) == toset(["vCenters to HSM OV03", "HSM OV03 to vCenters", "Bastion to HSM OV03"])
    error_message = "A VM-specified appliance without OneView, iLOs or hosts should skip those rules."
  }
}
