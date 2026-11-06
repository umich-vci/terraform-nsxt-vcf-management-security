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
  description = "Policy paths of each domain's groups."
  value       = { for k, d in module.domain : k => d.group_paths }
}

output "zone_group_paths" {
  description = "The management domain zone and each workload domain zone (keyed by NSX Manager cluster): the zone group's path and display name, and the groups statically included in it."
  value = {
    for k, z in module.zone : k => {
      zone         = z.group_paths.zone
      display_name = "${local.instance}_${local.zone_labels[k]}"
      member_paths = z.member_paths
    }
  }
}

output "policy_paths" {
  description = "Policy paths of all security policies."
  value = merge(
    module.fleet_policies.policy_paths,
    merge([for k, z in module.zone : { for p, path in z.policy_paths : "zone_${k}_${p}" => path }]...),
  )
}

output "hardware_support_managers" {
  description = "Per Hardware Support Manager: its group path, the vCenter groups allowed to and from it, and the services each way."
  value = {
    for k, h in var.hardware_support_managers : k => {
      group          = module.common.hsm_group_paths[k]
      vcenter_groups = [for d in distinct(h.domains) : module.domain[d].group_paths.vc]
      to_services    = h.to_hsm == null ? [module.common.service_paths["https"]] : h.to_hsm
      from_services  = h.from_hsm
    }
  }
}
