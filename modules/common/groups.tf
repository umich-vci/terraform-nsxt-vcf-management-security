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

# Hardware Support Managers, by exact VM name, IP addresses, or either. Not part of the design guide.
# They are not tagged; fleet-policies adds them to VCF_FLEET.
resource "nsxt_policy_group" "hsm" {
  for_each = var.hardware_support_managers

  nsx_id       = "HSM_${upper(each.key)}"
  display_name = "HSM_${upper(each.key)}"

  dynamic "criteria" {
    for_each = each.value.vm_name != null ? [each.value.vm_name] : []
    content {
      condition {
        member_type = "VirtualMachine"
        key         = "Name"
        operator    = "EQUALS"
        value       = criteria.value
      }
    }
  }

  dynamic "conjunction" {
    for_each = each.value.vm_name != null && length(each.value.ips) > 0 ? [1] : []
    content {
      operator = "OR"
    }
  }

  dynamic "criteria" {
    for_each = length(each.value.ips) > 0 ? [each.value.ips] : []
    content {
      ipaddress_expression {
        ip_addresses = criteria.value
      }
    }
  }
}
