# The common module on its own: built-in service lookup and service groups.

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
        "CIM-HTTPS"                     = "/infra/services/CIM-HTTPS"
      }
    }
  }
  mock_data "nsxt_policy_context_profile" {
    defaults = { path = "/infra/context-profiles/DNS" }
  }
  mock_resource "nsxt_policy_service" {
    defaults = { path = "/infra/services/MOCK" }
  }
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
  mock_resource "nsxt_policy_context_profile" {
    defaults = { path = "/infra/context-profiles/MOCK" }
  }
}

variables {
  external_services = {
    dns = ["192.0.2.53"]
    ntp = ["192.0.2.123"]
  }
  internet_fqdns = ["*.example.com"]
}

run "builtins_and_groups" {
  module {
    source = "./modules/common"
  }

  assert {
    condition     = output.service_paths["https"] == "/infra/services/HTTPS" && output.service_paths["salt"] == "/infra/services/MOCK"
    error_message = "Built-in services should come from the lookup and the rest from custom services."
  }
  assert {
    condition     = length(nsxt_policy_group.external["dns"].criteria) == 1 && length(nsxt_policy_group.external["siem"].criteria) == 0
    error_message = "A service with no addresses should get an empty group."
  }
  assert {
    condition     = nsxt_policy_group.external["backup"].nsx_id == "BACKUP_SVC" && nsxt_policy_group.external["log_archive"].nsx_id == "LOG_ARCHIVE_SVC"
    error_message = "Unexpected group names."
  }
}

run "missing_builtin_service" {
  command = plan

  module {
    source = "./modules/common"
  }

  override_data {
    target = data.nsxt_policy_services.all
    values = { items = { "HTTPS" = "/infra/services/HTTPS" } }
  }

  expect_failures = [output.service_paths]
}

run "custom_services" {
  module {
    source = "./modules/common"
  }

  assert {
    condition     = nsxt_policy_service.custom["amqps"].display_name == "TCP-5671" && nsxt_policy_service.custom["amqps"].description == "AMQP over TLS"
    error_message = "TCP/5671 should be the generic amqps service."
  }
  assert {
    condition     = nsxt_policy_service.custom["tcp_3512"].display_name == "TCP-3512" && nsxt_policy_service.custom["tcp_3512"].description == "TCP-3512"
    error_message = "TCP/3512 should be a generic custom service."
  }
  assert {
    condition     = !contains(keys(output.service_paths), "nsx_amqp") && !contains(keys(output.service_paths), "vc_db") && output.service_paths["cim_https"] == "/infra/services/CIM-HTTPS"
    error_message = "nsx_amqp and vc_db should be gone, and CIM-HTTPS should come from the built-in lookup."
  }
}
