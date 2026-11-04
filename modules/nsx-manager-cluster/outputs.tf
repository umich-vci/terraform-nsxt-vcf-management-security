output "group_paths" {
  description = "Policy paths of this NSX Manager cluster's groups; avi and ssp are null when not deployed."
  value = {
    nsx = nsxt_policy_group.named["nsx"].path
    avi = try(nsxt_policy_group.named["avi"].path, null)
    ssp = try(nsxt_policy_group.named["ssp"].path, null)
  }
}

output "ssp_domain" {
  description = "Domain hosting this cluster's SSP instance, or null."
  value       = var.ssp == null ? null : var.ssp_domain
}
