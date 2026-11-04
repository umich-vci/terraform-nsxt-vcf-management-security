# Wiring between the submodules, checked through the root outputs.

mock_provider "nsxt" {
  mock_data "nsxt_policy_services" {
    defaults = {
      items = {
        "HTTPS"                         = "/infra/services/HTTPS"
        "SSH"                           = "/infra/services/SSH"
        "RDP"                           = "/infra/services/RDP"
        "FTP"                           = "/infra/services/FTP"
        "ICMP ALL"                      = "/infra/services/ICMP-ALL"
        "ICMP Echo Request"             = "/infra/services/ICMP-Echo"
        "SMTP"                          = "/infra/services/SMTP"
        "SMTP_TLS"                      = "/infra/services/SMTP_TLS"
        "DNS-TCP"                       = "/infra/services/DNS-TCP"
        "DNS-UDP"                       = "/infra/services/DNS-UDP"
        "NTP"                           = "/infra/services/NTP"
        "DHCP-Server"                   = "/infra/services/DHCP-Server"
        "Microsoft Active Directory V1" = "/infra/services/AD"
        "Syslog (TCP)"                  = "/infra/services/Syslog-TCP"
        "Syslog (UDP)"                  = "/infra/services/Syslog-UDP"
        "NFS (TCP)"                     = "/infra/services/NFS-TCP"
        "VMware-iSCSI-Server"           = "/infra/services/iSCSI"
      }
    }
  }
  mock_data "nsxt_policy_vms" {
    defaults = { items = {} }
  }
  mock_data "nsxt_policy_context_profile" {
    defaults = { path = "/infra/context-profiles/DNS" }
  }
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
  mock_resource "nsxt_policy_service" {
    defaults = { path = "/infra/services/MOCK" }
  }
  mock_resource "nsxt_policy_context_profile" {
    defaults = { path = "/infra/context-profiles/MOCK" }
  }
}

# Each fleet management lookup matches its own VM, so the tag overlap check passes.
override_data {
  target = module.fleet_management.data.nsxt_policy_vms.tagged["ops"]
  values = { items = { "test-ops" = "bios-ops" } }
}
override_data {
  target = module.fleet_management.data.nsxt_policy_vms.tagged["sddc"]
  values = { items = { "sddc01" = "bios-sddc" } }
}
override_data {
  target = module.fleet_management.data.nsxt_policy_vms.tagged["license_server"]
  values = { items = { "lic01" = "bios-lic" } }
}
override_data {
  target = module.fleet_management.data.nsxt_policy_vms.tagged["license_hub"]
  values = { items = { "lhub01" = "bios-lhub" } }
}
override_data {
  target = module.fleet_management.data.nsxt_policy_vms.tagged["ssp_installer"]
  values = { items = { "test-sspi" = "bios-sspi" } }
}

# Distinct paths for the groups whose nesting is asserted below.
override_resource {
  target = module.nsx_manager_cluster["m01"].nsxt_policy_group.named["nsx"]
  values = { path = "/infra/domains/default/groups/M01_NSX" }
}
override_resource {
  target = module.nsx_manager_cluster["w01"].nsxt_policy_group.named["nsx"]
  values = { path = "/infra/domains/default/groups/W01_NSX" }
}
override_resource {
  target = module.nsx_manager_cluster["w01"].nsxt_policy_group.named["avi"]
  values = { path = "/infra/domains/default/groups/W01_AVI" }
}
override_resource {
  target = module.nsx_manager_cluster["w01"].nsxt_policy_group.named["ssp"]
  values = { path = "/infra/domains/default/groups/W01_SSP" }
}

variables {
  external_services = {
    bastion = ["192.0.2.10"]
    dns     = ["192.0.2.53"]
    ntp     = ["192.0.2.123"]
  }
  fleet_management = {
    vcf_operations_prefix             = "test-ops"
    vcf_operations_cloud_proxy_prefix = "cp01"
    vcf_management_services_prefix    = "vcfms-"
    vcf_automation_prefix             = "vcfa-"
    vcf_automation_lb_ips             = ["198.51.100.20"]
    sddc_manager_name                 = "sddc01"
    license_server_name               = "lic01"
    license_hub_name                  = "lhub01"
    ssp_installer_name                = "test-sspi"
  }
  nsx_manager_clusters = {
    m01 = { vm_name_prefix = "m01-nsx01" }
  }
  management_domain = {
    name                = "m01"
    vcenter_name        = "m01-vc01"
    nsx_manager_cluster = "m01"
    hosts               = ["198.51.100.0/27"]
  }
}

run "management_domain_only" {
  assert {
    condition     = keys(output.domain_group_paths) == ["m01"]
    error_message = "Only the management domain should exist."
  }
  assert {
    condition     = length(output.domain_group_paths["m01"].member_paths) == 2 && contains(output.domain_group_paths["m01"].member_paths, "/infra/domains/default/groups/M01_NSX")
    error_message = "The management domain should statically include its vCenter and NSX Manager groups only."
  }
  assert {
    condition     = output.domain_group_paths["m01"].avi == null && output.domain_group_paths["m01"].sup == null
    error_message = "No Avi or Supervisor groups were configured."
  }
  assert {
    condition     = toset(keys(output.policy_paths)) == toset(["fleet", "fleet_management", "infrastructure", "vcf_automation", "domain_m01"])
    error_message = "Unexpected set of policies."
  }
}

run "workload_domains_share_nsx_cluster" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = {
        vm_name_prefix = "w01-nsx01"
        avi            = { controller_prefix = "w01-avi01" }
        ssp            = { node_prefix = "w01-ssp-", service_pool = ["203.0.113.32/28"], domain = "w01" }
      }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"], supervisors = ["203.0.113.64/28"], avi_service_engines = ["203.0.113.96/28"] }
      w02 = { vcenter_name = "w02-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.16/28"] }
    }
  }

  assert {
    condition     = output.domain_group_paths["w01"].nsx == "/infra/domains/default/groups/W01_NSX" && output.domain_group_paths["w02"].nsx == "/infra/domains/default/groups/W01_NSX"
    error_message = "Both workload domains should use the shared cluster's NSX group."
  }
  assert {
    condition = alltrue([
      for d in ["w01", "w02"] : contains(output.domain_group_paths[d].member_paths, "/infra/domains/default/groups/W01_NSX") && contains(output.domain_group_paths[d].member_paths, "/infra/domains/default/groups/W01_AVI")
    ])
    error_message = "The shared NSX Manager and Avi controller groups should be nested into both workload domains."
  }
  assert {
    condition     = contains(output.domain_group_paths["w01"].member_paths, "/infra/domains/default/groups/W01_SSP") && !contains(output.domain_group_paths["w02"].member_paths, "/infra/domains/default/groups/W01_SSP") && !contains(output.domain_group_paths["m01"].member_paths, "/infra/domains/default/groups/W01_SSP")
    error_message = "The SSP should only be nested into its hosting domain."
  }
  assert {
    condition     = output.domain_group_paths["w01"].sup != null && output.domain_group_paths["w02"].sup == null
    error_message = "Only w01 has Supervisors."
  }
  assert {
    condition     = contains(keys(output.policy_paths), "domain_w01") && contains(keys(output.policy_paths), "domain_w02")
    error_message = "Each workload domain should get its own Environment policy."
  }
}

run "ssp_defaults_to_management_domain" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = {
        vm_name_prefix = "w01-nsx01"
        ssp            = { node_prefix = "w01-ssp-", service_pool = ["203.0.113.32/28"] }
      }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
    }
  }

  assert {
    condition     = contains(output.domain_group_paths["m01"].member_paths, "/infra/domains/default/groups/W01_SSP") && !contains(output.domain_group_paths["w01"].member_paths, "/infra/domains/default/groups/W01_SSP")
    error_message = "Without ssp.domain the SSP should be nested into the management domain."
  }
}

run "workload_domain_uses_management_nsx" {
  variables {
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "m01", hosts = ["203.0.113.0/28"] }
    }
  }

  assert {
    condition     = output.domain_group_paths["w01"].nsx == "/infra/domains/default/groups/M01_NSX" && contains(output.domain_group_paths["w01"].member_paths, "/infra/domains/default/groups/M01_NSX")
    error_message = "A workload domain sharing the management NSX Manager should nest M01_NSX."
  }
}

run "rejects_unknown_nsx_cluster" {
  command = plan
  variables {
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "nope", hosts = ["203.0.113.0/28"] }
    }
  }
  expect_failures = [var.workload_domains]
}

run "rejects_ssp_domain_on_other_cluster" {
  command = plan
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01", ssp = { node_prefix = "w01-ssp-", service_pool = ["203.0.113.32/28"], domain = "w02" } }
      w02 = { vm_name_prefix = "w02-nsx01" }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
      w02 = { vcenter_name = "w02-vc01", nsx_manager_cluster = "w02", hosts = ["203.0.113.16/28"] }
    }
  }
  expect_failures = [var.workload_domains]
}

run "rejects_avi_service_engines_without_avi" {
  command = plan
  variables {
    management_domain = {
      name                = "m01"
      vcenter_name        = "m01-vc01"
      nsx_manager_cluster = "m01"
      hosts               = ["198.51.100.0/27"]
      avi_service_engines = ["198.51.100.96/28"]
    }
  }
  expect_failures = [var.management_domain]
}

run "rejects_workload_key_equal_to_management" {
  command = plan
  variables {
    workload_domains = {
      m01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "m01", hosts = ["203.0.113.0/28"] }
    }
  }
  expect_failures = [var.workload_domains]
}

run "rejects_empty_prefix" {
  command = plan
  variables {
    nsx_manager_clusters = { m01 = { vm_name_prefix = "" } }
  }
  expect_failures = [var.nsx_manager_clusters]
}

run "rejects_bad_lockdown_action" {
  command = plan
  variables {
    lockdown_action = "REJECT"
  }
  expect_failures = [var.lockdown_action]
}
