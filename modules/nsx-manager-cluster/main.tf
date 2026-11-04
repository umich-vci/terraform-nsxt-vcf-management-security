locals {
  prefix = upper(var.name)

  # Grouped by VM name (MDS-REQD-CFG-003/006) so that the same groups can be nested into every
  # domain that shares this NSX Manager. VM tags would conflict between those domains.
  named = merge(
    { nsx = { group = "${local.prefix}_NSX", prefix = var.vm_name_prefix } },
    var.avi == null ? {} : { avi = { group = "${local.prefix}_AVI", prefix = var.avi.controller_prefix } },
    var.ssp == null ? {} : { ssp = { group = "${local.prefix}_SSP", prefix = var.ssp.node_prefix } },
  )
}

resource "nsxt_policy_group" "named" {
  for_each = local.named

  nsx_id       = each.value.group
  display_name = each.value.group

  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Name"
      operator    = "STARTSWITH"
      value       = each.value.prefix
    }
  }
}

# SSP Service IP Pool. The group tag places it in the nested group of the domain hosting the SSP.
resource "nsxt_policy_group" "ssp_svc" {
  count = var.ssp == null ? 0 : 1

  nsx_id       = "${local.prefix}_SSP_SVC"
  display_name = "${local.prefix}_SSP_SVC"
  group_type   = "IPAddress"

  tag {
    scope = var.ssp_domain
    tag   = "ssp_svc"
  }

  criteria {
    ipaddress_expression {
      ip_addresses = var.ssp.service_pool
    }
  }

  lifecycle {
    precondition {
      condition     = var.ssp_domain != null
      error_message = "ssp_domain must be set when an SSP instance is configured."
    }
  }
}
