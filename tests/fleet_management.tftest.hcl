# The fleet-management module on its own: group names, tagging and VCF_FM.

mock_provider "nsxt" {
  mock_data "nsxt_policy_vms" {
    defaults = { items = {} }
  }
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

override_data {
  target = data.nsxt_policy_vms.tagged["ops"]
  values = { items = { "test-ops-a" = "bios-ops-a", "test-ops-b" = "bios-ops-b" } }
}
override_data {
  target = data.nsxt_policy_vms.tagged["sddc"]
  values = { items = { "sddc01" = "bios-sddc" } }
}
override_data {
  target = data.nsxt_policy_vms.tagged["license_server"]
  values = { items = { "lic01" = "bios-lic" } }
}
override_data {
  target = data.nsxt_policy_vms.tagged["license_hub"]
  values = { items = { "lhub01" = "bios-lhub" } }
}
override_data {
  target = data.nsxt_policy_vms.tagged["ssp_installer"]
  values = { items = { "test-sspi" = "bios-sspi" } }
}
override_data {
  target = data.nsxt_policy_vms.tagged["ops_networks"]
  values = { items = { "opsnet01" = "bios-opsnet" } }
}

variables {
  instance = "VCF01"
  fleet_management = {
    vcf_operations_prefix             = "test-ops"
    vcf_operations_cloud_proxy_prefix = "cp01"
    vcf_management_services_prefix    = "vcfms-"
    vcf_automation_prefix             = "vcfa-"
    vcf_automation_lb_ips             = ["198.51.100.20"]
    sddc_manager_prefix               = "sddc01"
    license_server_prefix             = "lic01"
    license_hub_prefix                = "lhub01"
    ssp_installer_prefix              = "test-sspi"
  }
}

run "without_optional_components" {
  module {
    source = "./modules/fleet-management"
  }

  assert {
    condition     = toset([for g in nsxt_policy_group.tagged : g.nsx_id]) == toset(["VCF_OPS", "VCF01_SDDC", "VCF01_LIC", "VCF01_LHUB", "VCF01_SSPI01", "VCF_OPS_NET"])
    error_message = "Unexpected tag-based group names."
  }
  assert {
    condition     = toset([for g in nsxt_policy_group.named : g.nsx_id]) == toset(["VCF01_OPS_CP", "VCF01_OPS_NET_CN", "VCF_A"])
    error_message = "Unexpected name-based group names."
  }
  assert {
    condition     = !contains(keys(data.nsxt_policy_vms.tagged), "ops_networks") && length(nsxt_policy_group.named["ops_net_cn"].criteria) == 0
    error_message = "Without VCF Operations for Networks its VMs are not looked up and its collector group is empty."
  }
  assert {
    condition     = length(nsxt_policy_vm_tags.tagged) == 6 && nsxt_policy_vm_tags.tagged["ops/test-ops-b"].instance_id == "bios-ops-b"
    error_message = "Every matched VM should get one tag resource."
  }
  assert {
    condition     = one(nsxt_policy_vm_tags.tagged["ssp_installer/test-sspi"].tag).scope == "vcf_fm"
    error_message = "The SSP Installer should be tagged with the vcf_fm scope, not a domain scope."
  }
  assert {
    condition     = length(nsxt_policy_group.msvc.criteria) == 1 && length(nsxt_policy_group.vcf_a_lb["vcf_a_ext_lb"].criteria) == 0
    error_message = "Without an IP pool or external load balancer those criteria are absent."
  }
  assert {
    condition     = length(one(nsxt_policy_group.vcf_fm.criteria).path_expression[0].member_paths) == 1
    error_message = "VCF_FM nests its children (all mocked to one path here)."
  }
}

run "with_optional_components" {
  module {
    source = "./modules/fleet-management"
  }

  variables {
    fleet_management = {
      vcf_operations_prefix             = "test-ops"
      vcf_operations_cloud_proxy_prefix = "cp01"
      vcf_management_services_prefix    = "vcfms-"
      vcf_management_services_ip_pool   = ["198.51.100.64/26"]
      vcf_automation_prefix             = "vcfa-"
      vcf_automation_lb_ips             = ["198.51.100.20"]
      vcf_automation_external_lb_ips    = ["192.0.2.80"]
      sddc_manager_prefix               = "sddc01"
      license_server_prefix             = "lic01"
      license_hub_prefix                = "lhub01"
      ssp_installer_prefix              = "test-sspi"
      vcf_operations_networks           = { platform_prefix = "opsnet01", collector_prefix = "opsnetc" }
    }
  }

  assert {
    condition     = length(nsxt_policy_group.msvc.criteria) == 2 && length(nsxt_policy_group.msvc.conjunction) == 1
    error_message = "VCF01_MSVC should hold the node VMs OR the Management Services IP pool."
  }
  assert {
    condition     = contains(keys(nsxt_policy_vm_tags.tagged), "ops_networks/opsnet01") && length(nsxt_policy_group.named["ops_net_cn"].criteria) == 1
    error_message = "VCF Operations for Networks should be tagged and grouped when configured."
  }
}

run "rejects_vm_matched_by_two_prefixes" {
  command = plan

  module {
    source = "./modules/fleet-management"
  }

  override_data {
    target = data.nsxt_policy_vms.tagged["sddc"]
    values = { items = { "test-ops-a" = "bios-ops-a" } }
  }

  expect_failures = [nsxt_policy_vm_tags.tagged]
}
