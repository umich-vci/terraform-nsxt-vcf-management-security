locals {
  instance      = upper(var.vcf_instance_name)
  mgmt          = var.management_domain.name
  workload_keys = sort(keys(var.workload_domains))

  domains = merge(
    {
      (local.mgmt) = {
        vcenter_name        = var.management_domain.vcenter_name
        nsx_manager_cluster = var.management_domain.nsx_manager_cluster
        hosts               = var.management_domain.hosts
        edges               = var.management_domain.edges
        supervisors         = []
        avi_service_engines = var.management_domain.avi_service_engines
        ip_storage          = var.management_domain.ip_storage
        sequence_number     = 3
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
        ip_storage          = w.ip_storage
        sequence_number     = 4 + index(local.workload_keys, k)
      }
    },
  )
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

  name           = each.key
  vm_name_prefix = each.value.vm_name_prefix
  avi            = each.value.avi
  edges          = each.value.edges
  domains        = [for d, v in local.domains : d if v.nsx_manager_cluster == each.key]
  ssp            = each.value.ssp == null ? null : { node_prefix = each.value.ssp.node_prefix, service_pool = each.value.ssp.service_pool }
  ssp_domain     = each.value.ssp == null ? null : coalesce(each.value.ssp.domain, local.mgmt)
}

module "domain" {
  source   = "./modules/domain"
  for_each = local.domains

  name                = each.key
  instance            = local.instance
  vcenter_name        = each.value.vcenter_name
  hosts               = each.value.hosts
  edges               = each.value.edges
  supervisors         = each.value.supervisors
  avi_service_engines = each.value.avi_service_engines
  ip_storage          = each.value.ip_storage
  cluster_group_paths = module.nsx_manager_cluster[each.value.nsx_manager_cluster].group_paths
  hosted_ssp_paths    = [for c in module.nsx_manager_cluster : c.group_paths.ssp if c.ssp_domain == each.key]
  fleet_group_paths   = module.fleet_management.group_paths
  service_paths       = module.common.service_paths
  sequence_number     = each.value.sequence_number
  lockdown_action     = var.lockdown_action
}

module "fleet_policies" {
  source = "./modules/fleet-policies"

  domains               = { for k, d in module.domain : k => d.group_paths }
  fleet_group_paths     = module.fleet_management.group_paths
  external_group_paths  = module.common.group_paths
  service_paths         = module.common.service_paths
  context_profile_paths = module.common.context_profile_paths
  lockdown_action       = var.lockdown_action
}
