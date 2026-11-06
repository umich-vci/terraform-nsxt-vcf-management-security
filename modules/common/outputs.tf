output "service_paths" {
  description = "Policy paths of all NSX services, built-in and custom, by display name."
  value       = data.nsxt_policy_services.all.items
}

output "context_profile_paths" {
  description = "Policy paths of the context profiles used by the policies."
  value = {
    dns            = data.nsxt_policy_context_profile.dns.path
    internet_fqdns = nsxt_policy_context_profile.internet_fqdns.path
  }
}

output "group_paths" {
  description = "Policy paths of the infrastructure and external service groups."
  value       = { for k, g in nsxt_policy_group.external : k => g.path }
}
