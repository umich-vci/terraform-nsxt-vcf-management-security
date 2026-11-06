locals {
  prefix = upper(var.name)
  name   = coalesce(var.display_name, local.prefix)

  # Policy names as in the design guide: "VCF01 Management Domain Policy", "VCF01 Workload Domain (...) Policy".
  title = contains(keys(var.domains), var.management_domain) ? "Management Domain" : "Workload Domain ${local.name}"
  label = "${var.instance} ${local.title}"
  domain_titles = {
    for k in keys(var.domains) : k => k == var.management_domain ? "Management Domain" : "Workload Domain ${upper(k)}"
  }
  fleet = var.fleet_group_paths
  c     = var.cluster_group_paths
  zone  = nsxt_policy_group.zone.path

  vcs     = [for d in var.domains : d.vc]
  hosts   = [for d in var.domains : d.hosts if d.hosts != null]
  edges   = [for d in var.domains : d.edge if d.edge != null]
  sups    = [for d in var.domains : d.sup if d.sup != null]
  avi_ses = [for d in var.domains : d.avi_se if d.avi_se != null]

  nsx_and_avi  = concat([local.c.nsx], local.c.avi == null ? [] : [local.c.avi])
  member_paths = concat(local.vcs, local.nsx_and_avi, var.ssp_dfw ? [local.c.ssp] : [])
}

# Management domain zone or workload domain zone: the domains using one NSX Manager cluster, such as
# the guide's "Workload Domain #1/2 Zone". IP groups join by child group tag; the vCenter, NSX Manager,
# Avi controller and DFW-protected SSP groups by static inclusion (MDS-REQD-CFG-009).
resource "nsxt_policy_group" "zone" {
  nsx_id       = "${var.instance}_${local.prefix}"
  display_name = "${var.instance}_${local.name}"

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
