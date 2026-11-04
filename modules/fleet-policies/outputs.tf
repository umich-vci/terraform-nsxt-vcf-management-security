output "vcf_fleet_group_path" {
  description = "Policy path of the VCF_FLEET group."
  value       = nsxt_policy_group.vcf_fleet.path
}

output "policy_paths" {
  description = "Policy paths of the fleet-level security policies."
  value = {
    fleet            = nsxt_policy_security_policy.fleet.path
    fleet_management = nsxt_policy_security_policy.fleet_management.path
    infrastructure   = nsxt_policy_security_policy.infrastructure.path
    vcf_automation   = nsxt_policy_security_policy.vcf_automation.path
  }
}
