output "group_paths" {
  description = "Policy paths of the domain's groups; all but vc are null when not configured."
  value = {
    vc     = nsxt_policy_group.vc.path
    hosts  = try(nsxt_policy_group.ip["hosts"].path, null)
    edge   = try(nsxt_policy_group.ip["edge"].path, null)
    sup    = try(nsxt_policy_group.ip["sup"].path, null)
    avi_se = try(nsxt_policy_group.ip["avi_se"].path, null)
  }
}
