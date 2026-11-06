locals {
  external_groups = {
    bastion     = "BASTION"
    tools       = "TOOLS"
    backup      = "BACKUP_SVC"
    smtp        = "SMTP_SVC"
    siem        = "SIEM_SVC"
    dns         = "DNS_SVC"
    ntp         = "NTP_SVC"
    dhcp        = "DHCP_SVC"
    ad          = "AD_SVC"
    syslog      = "SYSLOG_SVC"
    log_archive = "LOG_ARCHIVE_SVC"
  }
}

resource "nsxt_policy_group" "external" {
  for_each = local.external_groups

  nsx_id       = each.value
  display_name = each.value
  group_type   = "IPAddress"

  dynamic "criteria" {
    for_each = length(var.external_services[each.key]) > 0 ? [1] : []
    content {
      ipaddress_expression {
        ip_addresses = var.external_services[each.key]
      }
    }
  }
}
