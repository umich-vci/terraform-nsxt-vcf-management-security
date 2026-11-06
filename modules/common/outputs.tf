output "service_paths" {
  description = "Policy paths of the services used by the policies, by logical name."
  value = merge(
    { for k, name in local.builtin_services : k => lookup(data.nsxt_policy_services.all.items, name, null) },
    { for k, s in nsxt_policy_service.custom : k => s.path },
  )

  precondition {
    condition     = length(local.missing_builtin_services) == 0
    error_message = "These built-in NSX services were not found: ${join(", ", local.missing_builtin_services)}."
  }
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
