locals {
  prefix = upper(var.name)

  # Static IP groups (MDS-REQD-CFG-007/008), created only when they have members. Each carries a
  # group tag with the domain as scope, which places it in the domain's nested group.
  ip_groups = {
    for k, g in {
      hosts   = { group = "${local.prefix}_HOSTS", ips = var.hosts }
      edge    = { group = "${local.prefix}_EDGE", ips = var.edges }
      sup     = { group = "${local.prefix}_SUP", ips = var.supervisors }
      avi_se  = { group = "${local.prefix}_AVI_SE", ips = var.avi_service_engines }
      storage = { group = "${local.prefix}_STORAGE", ips = var.ip_storage }
    } : k => g if length(g.ips) > 0
  }

  member_paths = concat(
    [nsxt_policy_group.vc.path, var.cluster_group_paths.nsx],
    var.cluster_group_paths.avi == null ? [] : [var.cluster_group_paths.avi],
    var.hosted_ssp_paths,
  )
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
    scope = var.name
    tag   = each.key
  }

  criteria {
    ipaddress_expression {
      ip_addresses = each.value.ips
    }
  }
}

# All components of the domain (MDS-REQD-CFG-009): IP groups by child group tag, and the vCenter,
# NSX Manager, Avi controller and SSP groups by static inclusion.
resource "nsxt_policy_group" "domain" {
  nsx_id       = "${var.instance}_${local.prefix}"
  display_name = "${var.instance}_${local.prefix}"

  criteria {
    condition {
      member_type = "Group"
      key         = "GroupType"
      operator    = "EQUALS"
      value       = "IPAddress"
    }
    condition {
      member_type = "Group"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "${var.name}|"
    }
  }

  conjunction {
    operator = "OR"
  }

  criteria {
    path_expression {
      member_paths = local.member_paths
    }
  }
}
