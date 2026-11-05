locals {
  prefix = upper(var.name)

  # Static IP groups (MDS-REQD-CFG-007/008), created only when they have members. Each carries a
  # group tag with the zone as scope, which places it in the zone group.
  ip_groups = {
    for k, g in {
      hosts  = { group = "${local.prefix}_HOSTS", ips = var.hosts }
      edge   = { group = "${local.prefix}_EDGE", ips = var.edges }
      sup    = { group = "${local.prefix}_SUP", ips = var.supervisors }
      avi_se = { group = "${local.prefix}_AVI_SE", ips = var.avi_service_engines }
    } : k => g if length(g.ips) > 0
  }
}

# By VM name, because NSX tags are lost during a vCenter reduced downtime upgrade (MDS-REQD-CFG-002).
resource "nsxt_policy_group" "vc" {
  nsx_id       = "${local.prefix}_VC"
  display_name = "${local.prefix}_VC"

  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Name"
      operator    = "EQUALS"
      value       = var.vcenter_name
    }
  }
}

resource "nsxt_policy_group" "ip" {
  for_each = local.ip_groups

  nsx_id       = each.value.group
  display_name = each.value.group
  group_type   = "IPAddress"

  tag {
    scope = var.zone
    tag   = "${var.name}_${each.key}"
  }

  criteria {
    ipaddress_expression {
      ip_addresses = each.value.ips
    }
  }
}
