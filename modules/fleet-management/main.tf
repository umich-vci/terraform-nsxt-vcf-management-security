locals {
  fm = var.fleet_management

  # Components grouped by NSX tag (MDS-REQD-CFG-012). Each is tagged vcf_fm|<tag>. Single-instance
  # components are matched by their exact VM name, the others by VM name prefix.
  tagged = {
    ops            = { group = "VCF_OPS", tag = "ops", match = local.fm.vcf_operations_prefix, exact = false }
    sddc           = { group = "${var.instance}_SDDC", tag = "sddc", match = local.fm.sddc_manager_name, exact = true }
    license_server = { group = "${var.instance}_LIC", tag = "lic", match = local.fm.license_server_name, exact = true }
    license_hub    = { group = "${var.instance}_LHUB", tag = "lhub", match = local.fm.license_hub_name, exact = true }
    ssp_installer  = { group = "${var.instance}_SSPI01", tag = "sspi", match = local.fm.ssp_installer_name, exact = true }
    ops_networks   = { group = "VCF_OPS_NET", tag = "ops_net", match = try(local.fm.vcf_operations_networks.platform_prefix, null), exact = false }
  }
  tagged_lookups = { for k, c in local.tagged : k => c if c.match != null }

  # Components grouped by VM name prefix (MDS-REQD-CFG-010/011). A null prefix gives an empty group.
  named = {
    ops_cp     = { group = "${var.instance}_OPS_CP", prefix = local.fm.vcf_operations_cloud_proxy_prefix }
    ops_net_cn = { group = "${var.instance}_OPS_NET_CN", prefix = try(local.fm.vcf_operations_networks.collector_prefix, null) }
    vcf_a      = { group = "VCF_A", prefix = local.fm.vcf_automation_prefix }
  }

  tagged_vms = merge([
    for k, d in data.nsxt_policy_vms.tagged : {
      for name, id in d.items : "${k}/${name}" => { id = id, tag = local.tagged[k].tag }
    }
  ]...)
  tagged_vm_ids = [for vm in values(local.tagged_vms) : vm.id]
}

data "nsxt_policy_vms" "tagged" {
  for_each = local.tagged_lookups

  display_name = "^${replace(each.value.match, ".", "\\.")}${each.value.exact ? "$" : ""}"
}

# nsxt_policy_vm_tags owns the whole tag set of a VM, so every VM must be matched by exactly one lookup.
resource "nsxt_policy_vm_tags" "tagged" {
  for_each = local.tagged_vms

  instance_id = each.value.id

  tag {
    scope = "vcf_fm"
    tag   = each.value.tag
  }

  lifecycle {
    precondition {
      condition     = length(local.tagged_vm_ids) == length(distinct(local.tagged_vm_ids))
      error_message = "A VM matches more than one fleet management VM name or prefix; make them unique."
    }
  }
}

check "tagged_vms_found" {
  assert {
    condition     = alltrue([for d in data.nsxt_policy_vms.tagged : length(d.items) > 0])
    error_message = "No VMs matched the VM name or prefix for: ${join(", ", [for k, d in data.nsxt_policy_vms.tagged : k if length(d.items) == 0])}."
  }
}

resource "nsxt_policy_group" "tagged" {
  for_each = local.tagged

  nsx_id       = each.value.group
  display_name = each.value.group

  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "vcf_fm|${each.value.tag}"
    }
  }
}

resource "nsxt_policy_group" "named" {
  for_each = local.named

  nsx_id       = each.value.group
  display_name = each.value.group

  dynamic "criteria" {
    for_each = each.value.prefix != null ? [each.value.prefix] : []
    content {
      condition {
        member_type = "VirtualMachine"
        key         = "Name"
        operator    = "STARTSWITH"
        value       = criteria.value
      }
    }
  }
}

# Log management and the other Management Services are reached through load balancer VIPs taken from
# the Management Services IP pool, so the group holds the node VMs and that pool.
resource "nsxt_policy_group" "msvc" {
  nsx_id       = "${var.instance}_MSVC"
  display_name = "${var.instance}_MSVC"

  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Name"
      operator    = "STARTSWITH"
      value       = local.fm.vcf_management_services_prefix
    }
  }

  dynamic "conjunction" {
    for_each = length(local.fm.vcf_management_services_ip_pool) > 0 ? [1] : []
    content {
      operator = "OR"
    }
  }

  dynamic "criteria" {
    for_each = length(local.fm.vcf_management_services_ip_pool) > 0 ? [1] : []
    content {
      ipaddress_expression {
        ip_addresses = local.fm.vcf_management_services_ip_pool
      }
    }
  }
}

resource "nsxt_policy_group" "vcf_a_lb" {
  for_each = {
    vcf_a_lb     = { group = "VCF_A_LB", ips = local.fm.vcf_automation_lb_ips }
    vcf_a_ext_lb = { group = "VCF_A_EXT_LB", ips = local.fm.vcf_automation_external_lb_ips }
  }

  nsx_id       = each.value.group
  display_name = each.value.group
  group_type   = "IPAddress"

  dynamic "criteria" {
    for_each = length(each.value.ips) > 0 ? [1] : []
    content {
      ipaddress_expression {
        ip_addresses = each.value.ips
      }
    }
  }
}

resource "nsxt_policy_group" "vcf_fm" {
  nsx_id       = "VCF_FM"
  display_name = "VCF_FM"

  criteria {
    path_expression {
      member_paths = concat(
        [for g in nsxt_policy_group.tagged : g.path],
        [for g in nsxt_policy_group.named : g.path],
        [nsxt_policy_group.msvc.path],
      )
    }
  }
}
