output "group_paths" {
  description = "Policy paths of this NSX Manager cluster's groups; avi, ssp and ssp_svc are null when not configured."
  value = {
    nsx     = nsxt_policy_group.named["nsx"].path
    avi     = try(nsxt_policy_group.named["avi"].path, null)
    ssp     = try(nsxt_policy_group.named["ssp"].path, nsxt_policy_group.ip["ssp"].path, null)
    ssp_svc = try(nsxt_policy_group.ip["ssp_svc"].path, null)
  }
}

output "ssp_dfw" {
  description = "Whether this cluster's SSP VMs run in the management domain and are protected by the DFW."
  value       = local.ssp_dfw
}
