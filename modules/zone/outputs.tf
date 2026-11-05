output "group_paths" {
  description = "Policy paths the fleet-level policies use: the zone group, its vCenter, NSX Manager and Avi controller groups, and its Supervisor groups."
  value = {
    zone        = nsxt_policy_group.zone.path
    vcs         = local.vcs
    nsx_and_avi = local.nsx_and_avi
    sups        = local.sups
  }
}

output "member_paths" {
  description = "Groups statically included in the zone group."
  value       = local.member_paths
}

output "policy_paths" {
  description = "Policy paths of the zone's Environment and Application policies."
  value = merge(
    { environment = nsxt_policy_security_policy.environment.path },
    { for k, p in nsxt_policy_security_policy.vcenter : "vcenter_${k}" => p.path },
    { for p in nsxt_policy_security_policy.nsx : "nsx" => p.path },
    { for p in nsxt_policy_security_policy.avi : "avi" => p.path },
    { for p in nsxt_policy_security_policy.ssp : "ssp" => p.path },
  )
}
