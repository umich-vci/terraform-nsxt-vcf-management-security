# The common module on its own: custom services, the service lookup and service groups.

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
        "TCP-5480"                      = "/infra/services/TCP-5480"
        "TCP-6443"                      = "/infra/services/TCP-6443"
        "TCP-1514"                      = "/infra/services/TCP-1514"
        "TCP-9543"                      = "/infra/services/TCP-9543"
        "TCP-4505_4506"                 = "/infra/services/TCP-4505_4506"
        "TCP-1991"                      = "/infra/services/TCP-1991"
        "UDP-2055"                      = "/infra/services/UDP-2055"
        "TCP-9092"                      = "/infra/services/TCP-9092"
        "TCP-1443"                      = "/infra/services/TCP-1443"
        "TCP-6500"                      = "/infra/services/TCP-6500"
        "TCP-6501_6502"                 = "/infra/services/TCP-6501_6502"
        "TCP-7475_7476"                 = "/infra/services/TCP-7475_7476"
        "TCP-1234_1235"                 = "/infra/services/TCP-1234_1235"
        "TCP-5671"                      = "/infra/services/TCP-5671"
        "TCP-8443"                      = "/infra/services/TCP-8443"
        "TCP-30000_30005"               = "/infra/services/TCP-30000_30005"
        "TCP-3512"                      = "/infra/services/TCP-3512"
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
    condition     = output.service_paths["HTTPS"] == "/infra/services/HTTPS" && output.service_paths["TCP-4505_4506"] == "/infra/services/TCP-4505_4506"
    error_message = "Built-in and custom services should both come from the lookup, by display name."
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

run "custom_services" {
  module {
    source = "./modules/common"
  }

  assert {
    condition     = alltrue([for k, s in nsxt_policy_service.custom : s.display_name == k])
    error_message = "Each custom service's display name should be its key, the name rules look it up by."
  }
  assert {
    condition     = nsxt_policy_service.custom["TCP-5671"].description == "AMQP over TLS" && nsxt_policy_service.custom["TCP-3512"].description == "TCP-3512"
    error_message = "TCP/5671 and TCP/3512 should be generic custom services."
  }
  assert {
    condition     = !contains(keys(nsxt_policy_service.custom), "TCP-5432")
    error_message = "The TCP/5432 (vc_db) service should be gone."
  }
}
