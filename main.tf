locals {
  instance = upper(var.vcf_instance_name)
  mgmt     = var.management_domain.name

  domains = merge(
    {
      (local.mgmt) = {
        vcenter_name        = var.management_domain.vcenter_name
        nsx_manager_cluster = var.management_domain.nsx_manager_cluster
        hosts               = var.management_domain.hosts
        edges               = var.management_domain.edges
        supervisors         = []
        avi_service_engines = var.management_domain.avi_service_engines
      }
    },
    {
      for k, w in var.workload_domains : k => {
        vcenter_name        = w.vcenter_name
        nsx_manager_cluster = w.nsx_manager_cluster
        hosts               = w.hosts
        edges               = w.edges
        supervisors         = w.supervisors
        avi_service_engines = w.avi_service_engines
      }
    },
  )

  # Management domain zone first, then the workload domain zones; each covers the domains using one
  # NSX Manager cluster.
  mgmt_zone  = var.management_domain.nsx_manager_cluster
  zone_order = concat([local.mgmt_zone], sort([for k in keys(var.nsx_manager_clusters) : k if k != local.mgmt_zone]))

  # Display label of each zone: the domains using its NSX Manager. IDs keep using the cluster key, so a
  # domain joining or leaving an NSX Manager only renames groups and policies in place. Long domain
  # lists fall back to the key so that display names stay within NSX's 255-character limit.
  zone_domain_labels = {
    for c in keys(var.nsx_manager_clusters) : c => upper(join("_", concat(
      c == local.mgmt_zone ? [local.mgmt] : [],
      sort([for k, w in var.workload_domains : k if w.nsx_manager_cluster == c]),
    )))
  }
  zone_labels = {
    for c, cl in var.nsx_manager_clusters : c => (
      cl.display_name != null ? upper(cl.display_name) :
      length(local.zone_domain_labels[c]) <= 128 ? local.zone_domain_labels[c] : upper(c)
    )
  }
}

module "common" {
  source = "./modules/common"

  external_services = var.external_services
  internet_fqdns    = var.internet_fqdns
}

module "fleet_management" {
  source = "./modules/fleet-management"

  instance         = local.instance
  fleet_management = var.fleet_management
}

module "nsx_manager_cluster" {
  source   = "./modules/nsx-manager-cluster"
  for_each = var.nsx_manager_clusters

  name                     = each.key
  display_name             = local.zone_labels[each.key]
  vm_name_prefix           = each.value.vm_name_prefix
  avi                      = each.value.avi
  ssp                      = each.value.ssp == null ? null : { node_prefix = each.value.ssp.node_prefix, node_pool = each.value.ssp.node_pool, service_pool = each.value.ssp.service_pool }
  ssp_in_management_domain = each.value.ssp == null ? true : coalesce(each.value.ssp.domain, local.mgmt) == local.mgmt
}

module "domain" {
  source   = "./modules/domain"
  for_each = local.domains

  name                = each.key
  zone                = each.value.nsx_manager_cluster
  vcenter_name        = each.value.vcenter_name
  hosts               = each.value.hosts
  edges               = each.value.edges
  supervisors         = each.value.supervisors
  avi_service_engines = each.value.avi_service_engines
}

module "zone" {
  source   = "./modules/zone"
  for_each = var.nsx_manager_clusters

  name                        = each.key
  display_name                = local.zone_labels[each.key]
  management_domain           = local.mgmt
  instance                    = local.instance
  domains                     = { for k, d in module.domain : k => d.group_paths if local.domains[k].nsx_manager_cluster == each.key }
  cluster_group_paths         = module.nsx_manager_cluster[each.key].group_paths
  nsx_dfw                     = each.key != local.mgmt_zone
  ssp_dfw                     = module.nsx_manager_cluster[each.key].ssp_dfw
  fleet_group_paths           = module.fleet_management.group_paths
  service_paths               = module.common.service_paths
  sequence_number             = 3 + index(local.zone_order, each.key)
  application_sequence_number = 10 + 100 * index(local.zone_order, each.key)
  lockdown_action             = var.lockdown_action
  application_lockdown_action = var.application_lockdown_action
}

module "fleet_policies" {
  source = "./modules/fleet-policies"

  zones                       = { for k, z in module.zone : k => z.group_paths }
  dfw_ssp_paths               = [for c in module.nsx_manager_cluster : c.group_paths.ssp if c.ssp_dfw]
  ops_networks_enabled        = var.fleet_management.vcf_operations_networks != null
  fleet_group_paths           = module.fleet_management.group_paths
  external_group_paths        = module.common.group_paths
  service_paths               = module.common.service_paths
  context_profile_paths       = module.common.context_profile_paths
  lockdown_action             = var.lockdown_action
  application_lockdown_action = var.application_lockdown_action
}
