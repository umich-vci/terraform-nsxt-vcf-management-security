locals {
  prefix  = upper(var.name)
  label   = coalesce(var.display_name, local.prefix)
  ssp_dfw = var.ssp != null && var.ssp_in_management_domain

  # Grouped by VM name (MDS-REQD-CFG-003/006). These VMs run in the management domain.
  named = merge(
    { nsx = { id = "${local.prefix}_NSX", name = "${local.label}_NSX", prefix = var.vm_name_prefix } },
    var.avi == null ? {} : { avi = { id = "${local.prefix}_AVI", name = "${local.label}_AVI", prefix = var.avi.controller_prefix } },
    local.ssp_dfw ? { ssp = { id = "${local.prefix}_SSP", name = "${local.label}_SSP", prefix = var.ssp.node_prefix } } : {},
  )

  # IP groups, tagged with the cluster key as scope, which places them in the zone of the domains using it.
  ip_groups = merge(
    var.ssp == null ? {} : { ssp_svc = { id = "${local.prefix}_SSP_SVC", name = "${local.label}_SSP_SVC", ips = var.ssp.service_pool } },
    var.ssp != null && !local.ssp_dfw ? { ssp = { id = "${local.prefix}_SSP", name = "${local.label}_SSP", ips = var.ssp.node_pool } } : {},
  )
}

resource "nsxt_policy_group" "named" {
  for_each = local.named

  nsx_id       = each.value.id
  display_name = each.value.name

  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Name"
      operator    = "STARTSWITH"
      value       = each.value.prefix
    }
  }
}

resource "nsxt_policy_group" "ip" {
  for_each = local.ip_groups

  nsx_id       = each.value.id
  display_name = each.value.name
  group_type   = "IPAddress"

  tag {
    scope = var.name
    tag   = each.key
  }

  criteria {
    ipaddress_expression {
      ip_addresses = each.value.ips
    }
  }
}
