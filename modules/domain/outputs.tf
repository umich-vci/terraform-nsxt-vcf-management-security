output "group_paths" {
  description = "Policy paths of the domain's groups; nsx and avi are those of the NSX Manager cluster it uses, sup is null without Supervisors."
  value = {
    domain = nsxt_policy_group.domain.path
    vc     = nsxt_policy_group.vc.path
    nsx    = var.cluster_group_paths.nsx
    avi    = var.cluster_group_paths.avi
    sup    = try(nsxt_policy_group.ip["sup"].path, null)
  }
}

output "member_paths" {
  description = "Groups statically included in the domain's nested group."
  value       = local.member_paths
}

output "policy_path" {
  description = "Policy path of the domain's Environment policy."
  value       = nsxt_policy_security_policy.environment.path
}
