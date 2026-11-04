output "fleet_group_paths" {
  description = "Policy paths of VCF_FLEET and the fleet management groups."
  value       = merge(module.fleet_management.group_paths, { vcf_fleet = module.fleet_policies.vcf_fleet_group_path })
}

output "external_group_paths" {
  description = "Policy paths of the infrastructure and external service groups."
  value       = module.common.group_paths
}

output "nsx_manager_cluster_group_paths" {
  description = "Policy paths of each NSX Manager cluster's groups."
  value       = { for k, c in module.nsx_manager_cluster : k => c.group_paths }
}

output "domain_group_paths" {
  description = "Policy paths of each domain's groups, with the groups statically included in its nested group."
  value       = { for k, d in module.domain : k => merge(d.group_paths, { member_paths = d.member_paths }) }
}

output "policy_paths" {
  description = "Policy paths of all security policies."
  value = merge(
    module.fleet_policies.policy_paths,
    { for k, d in module.domain : "domain_${k}" => d.policy_path },
  )
}
