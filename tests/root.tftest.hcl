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
        "HTTP"                          = "/infra/services/HTTP"
        "Update Manager"                = "/infra/services/Update-Manager"
        "VMware-UpdateMgr-VUM"          = "/infra/services/VUM"
        "Vmware-UpdateMgr-update"       = "/infra/services/VUM-update"
        "VMware-ESXi5.x-UDP"            = "/infra/services/ESXi-UDP"
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
override_resource {
  target = module.nsx_manager_cluster["w01"].nsxt_policy_group.ip["ssp"]
  values = { path = "/infra/domains/default/groups/W01_SSP_IP" }
}
override_resource {
  target = module.domain["w01"].nsxt_policy_group.vc
  values = { path = "/infra/domains/default/groups/W01_VC" }
}
override_resource {
  target = module.domain["w02"].nsxt_policy_group.vc
  values = { path = "/infra/domains/default/groups/W02_VC" }
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
    condition     = keys(output.zone_group_paths) == ["m01"] && keys(output.domain_group_paths) == ["m01"]
    error_message = "Only the management zone and domain should exist."
  }
  assert {
    condition     = length(output.zone_group_paths["m01"].member_paths) == 2 && contains(output.zone_group_paths["m01"].member_paths, "/infra/domains/default/groups/M01_NSX")
    error_message = "The management zone should statically include its vCenter and NSX Manager groups only."
  }
  assert {
    condition = toset(keys(output.policy_paths)) == toset([
      "fleet", "fleet_management", "infrastructure", "vcf_operations", "vcf_automation",
      "zone_m01_environment", "zone_m01_vcenter_m01",
    ])
    error_message = "Unexpected set of policies: ${jsonencode(keys(output.policy_paths))}"
  }
}

run "workload_domains_share_nsx_cluster" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = {
        vm_name_prefix = "w01-nsx01"
        avi            = { controller_prefix = "w01-avi01" }
        ssp            = { node_pool = ["203.0.113.80/28"], service_pool = ["203.0.113.32/28"], domain = "w01" }
      }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"], supervisors = ["203.0.113.64/28"], avi_service_engines = ["203.0.113.96/28"] }
      w02 = { vcenter_name = "w02-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.16/28"] }
    }
  }

  assert {
    condition     = toset(keys(output.zone_group_paths)) == toset(["m01", "w01"])
    error_message = "Two workload domains sharing an NSX Manager should form a single zone."
  }
  assert {
    condition = toset(output.zone_group_paths["w01"].member_paths) == toset([
      "/infra/domains/default/groups/W01_VC", "/infra/domains/default/groups/W02_VC",
      "/infra/domains/default/groups/W01_NSX", "/infra/domains/default/groups/W01_AVI",
    ])
    error_message = "The zone should include both vCenters, the NSX Managers and Avi; the workload-domain SSP joins by IP group tag."
  }
  assert {
    condition     = alltrue([for p in ["zone_w01_environment", "zone_w01_vcenter_w01", "zone_w01_vcenter_w02", "zone_w01_nsx", "zone_w01_avi"] : contains(keys(output.policy_paths), p)]) && !contains(keys(output.policy_paths), "zone_w01_ssp")
    error_message = "The shared zone should get one Environment policy, a vCenter policy per domain, and NSX and Avi policies; an SSP outside the management domain gets none."
  }
  assert {
    condition     = output.nsx_manager_cluster_group_paths["w01"].ssp == "/infra/domains/default/groups/W01_SSP_IP"
    error_message = "An SSP in a workload domain should be grouped by IP."
  }
}

run "ssp_in_management_domain" {
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
    condition     = contains(output.zone_group_paths["w01"].member_paths, "/infra/domains/default/groups/W01_SSP") && !contains(output.zone_group_paths["m01"].member_paths, "/infra/domains/default/groups/W01_SSP")
    error_message = "The SSP belongs to its NSX Manager's zone even when its VMs run in the management domain."
  }
  assert {
    condition     = contains(keys(output.policy_paths), "zone_w01_ssp")
    error_message = "An SSP in the management domain should get an Application policy."
  }
}

run "workload_domain_uses_management_nsx" {
  variables {
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "m01", hosts = ["203.0.113.0/28"] }
    }
  }

  assert {
    condition     = keys(output.zone_group_paths) == ["m01"] && contains(output.zone_group_paths["m01"].member_paths, "/infra/domains/default/groups/W01_VC")
    error_message = "A workload domain sharing the management NSX Manager should join the management zone."
  }
  assert {
    condition     = !contains(keys(output.policy_paths), "zone_m01_nsx") && contains(keys(output.policy_paths), "zone_m01_vcenter_w01")
    error_message = "The management NSX Manager stays DFW-excluded (no NSX policy); each vCenter still gets its policy."
  }
}

run "zone_display_names" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01" }
      w05 = { vm_name_prefix = "w05-nsx01", display_name = "lab" }
    }
    workload_domains = {
      w02 = { vcenter_name = "w02-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.16/28"] }
      w05 = { vcenter_name = "w05-vc01", nsx_manager_cluster = "w05", hosts = ["203.0.113.32/28"] }
    }
  }

  assert {
    condition     = output.zone_group_paths["m01"].display_name == "VCF01_M01" && output.zone_group_paths["w01"].display_name == "VCF01_W01_W02"
    error_message = "Zone display names should list the domains using each NSX Manager: ${jsonencode(output.zone_group_paths)}"
  }
  assert {
    condition     = output.zone_group_paths["w05"].display_name == "VCF01_LAB"
    error_message = "display_name should override the domain list."
  }
}

run "long_zone_display_name_falls_back_to_key" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01" }
    }
    workload_domains = { d01-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.1"] }, d02-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d02-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.2"] }, d03-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d03-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.3"] }, d04-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d04-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.4"] }, d05-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d05-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.5"] }, d06-xxxxxxxxxxxxxxxxxxxx = { vcenter_name = "d06-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.6"] } }
  }

  assert {
    condition     = output.zone_group_paths["w01"].display_name == "VCF01_W01"
    error_message = "A domain list over 128 characters should fall back to the cluster key."
  }
}

run "hardware_support_manager_vcenters" {
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01" }
      w05 = { vm_name_prefix = "w05-nsx01" }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
      w05 = { vcenter_name = "w05-vc01", nsx_manager_cluster = "w05", hosts = ["203.0.113.16/28"] }
    }
    hardware_support_managers = {
      oneview = { vm_name = "m01-hsm01", domains = ["m01", "w01"] }
      ome     = { ips = ["198.51.100.70"], domains = ["w05"], to_hsm = ["/infra/services/SNMP"], from_hsm = ["/infra/services/HTTPS"] }
    }
  }

  assert {
    condition     = output.hardware_support_managers["oneview"].vcenter_groups == ["/infra/domains/default/groups/MOCK", "/infra/domains/default/groups/W01_VC"]
    error_message = "An HSM should be allowed for the vCenters of its domains only: ${jsonencode(output.hardware_support_managers)}"
  }
  assert {
    condition = (
      jsonencode(output.hardware_support_managers["oneview"].to_services) == jsonencode(["/infra/services/HTTPS"]) &&
      length(output.hardware_support_managers["oneview"].from_services) == 0 &&
      jsonencode(output.hardware_support_managers["ome"].to_services) == jsonencode(["/infra/services/SNMP"]) &&
      jsonencode(output.hardware_support_managers["ome"].from_services) == jsonencode(["/infra/services/HTTPS"])
    )
    error_message = "to_hsm should default to the built-in HTTPS and from_hsm to none; given lists pass through."
  }
}

run "rejects_hsm_unknown_domain" {
  command = plan
  variables {
    hardware_support_managers = {
      oneview = { vm_name = "m01-hsm01", domains = ["w09"] }
    }
  }
  expect_failures = [var.hardware_support_managers]
}

run "rejects_hsm_without_vm_or_ips" {
  command = plan
  variables {
    hardware_support_managers = {
      oneview = { domains = ["m01"] }
    }
  }
  expect_failures = [var.hardware_support_managers]
}

run "rejects_hsm_service_name_instead_of_path" {
  command = plan
  variables {
    hardware_support_managers = {
      oneview = { vm_name = "m01-hsm01", domains = ["m01"], to_hsm = ["HTTPS"] }
    }
  }
  expect_failures = [var.hardware_support_managers]
}

run "rejects_long_key" {
  command = plan
  variables {
    vcf_instance_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.vcf_instance_name]
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

run "rejects_unused_nsx_cluster" {
  command = plan
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w09 = { vm_name_prefix = "w09-nsx01" }
    }
  }
  expect_failures = [var.workload_domains]
}

run "rejects_ssp_domain_on_other_cluster" {
  command = plan
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01", ssp = { node_pool = ["203.0.113.80/28"], service_pool = ["203.0.113.32/28"], domain = "w02" } }
      w02 = { vm_name_prefix = "w02-nsx01" }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
      w02 = { vcenter_name = "w02-vc01", nsx_manager_cluster = "w02", hosts = ["203.0.113.16/28"] }
    }
  }
  expect_failures = [var.workload_domains]
}

run "rejects_workload_ssp_without_node_pool" {
  command = plan
  variables {
    nsx_manager_clusters = {
      m01 = { vm_name_prefix = "m01-nsx01" }
      w01 = { vm_name_prefix = "w01-nsx01", ssp = { node_prefix = "w01-ssp-", service_pool = ["203.0.113.32/28"], domain = "w01" } }
    }
    workload_domains = {
      w01 = { vcenter_name = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
    }
  }
  expect_failures = [var.management_domain]
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

run "rejects_bad_lockdown_actions" {
  command = plan
  variables {
    lockdown_action             = "REJECT"
    application_lockdown_action = "REJECT"
  }
  expect_failures = [var.lockdown_action, var.application_lockdown_action]
}
