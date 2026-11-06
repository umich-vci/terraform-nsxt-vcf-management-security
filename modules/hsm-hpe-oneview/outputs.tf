output "group_paths" {
  description = "Policy paths of the appliance groups, which join VCF_FLEET."
  value       = [for g in nsxt_policy_group.appliance : g.path]
}

output "rules" {
  description = "Rules for the VCF Fleet Policy: display_name, source_groups, destination_groups, services, direction."
  value       = local.rules
}

output "hsms" {
  description = "Per appliance: its group path, the paths of its OneView and iLO groups (null when not given), and the names of its rules."
  value = {
    for k, h in var.hsms : k => {
      group   = nsxt_policy_group.appliance[k].path
      oneview = try(nsxt_policy_group.oneview[k].path, null)
      ilo     = try(nsxt_policy_group.ilo[k].path, null)
      rules   = [for r in local.rules_by_hsm[k] : r.display_name]
    }
  }
}
