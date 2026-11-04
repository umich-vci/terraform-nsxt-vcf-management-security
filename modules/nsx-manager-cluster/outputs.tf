output "group_paths" {
  description = "Policy paths of this NSX Manager cluster's groups; avi, ssp and edge are null when not configured."
  value = {
    nsx  = nsxt_policy_group.named["nsx"].path
    avi  = try(nsxt_policy_group.named["avi"].path, null)
    ssp  = try(nsxt_policy_group.named["ssp"].path, null)
    edge = try(nsxt_policy_group.edge[0].path, null)
  }
}

output "ssp_domain" {
  description = "Domain hosting this cluster's SSP instance, or null."
  value       = var.ssp == null ? null : var.ssp_domain
}
