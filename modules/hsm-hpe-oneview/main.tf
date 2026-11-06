# HPE OneView for VMware vCenter, the vSphere Lifecycle Manager Hardware Support Manager for HPE
# servers. Not part of the design guide. Ports follow HPE's "HPE OneView for VMware vCenter" open ports
# diagram (document sd00008393en_us). That the iLO opens TCP/3512 and 443 to the appliance is read from
# the diagram, where the line ends at the iLO.
#
# The groups and a vendor-neutral list of rules are handed to fleet-policies, which places the rules
# in the VCF Fleet Policy. The appliance group joins VCF_FLEET.

locals {
  svc = var.service_paths

  rules_by_hsm = {
    for k, h in var.hsms : k => [
      for r in [
        # Enforced at the vCenters, so these apply to an HSM given only by IP as well.
        { name = "vCenters to HSM ${upper(k)}", src = h.vcs, dst = [nsxt_policy_group.appliance[k].path], svc = [local.svc["https"], local.svc["tcp_3512"]], dir = "IN_OUT", vm = false },
        { name = "HSM ${upper(k)} to vCenters", src = [nsxt_policy_group.appliance[k].path], dst = h.vcs, svc = [local.svc["https"]], dir = "IN_OUT", vm = false },
        # The far end of these is not DFW-protected (IP groups, ESX vmkernel), so they only take effect
        # at an appliance VM.
        { name = "HSM ${upper(k)} to OneView", src = [nsxt_policy_group.appliance[k].path], dst = try([nsxt_policy_group.oneview[k].path], []), svc = [local.svc["https"], local.svc["amqps"]], dir = "IN_OUT", vm = true },
        { name = "HSM ${upper(k)} to iLOs", src = [nsxt_policy_group.appliance[k].path], dst = try([nsxt_policy_group.ilo[k].path], []), svc = [local.svc["http"], local.svc["https"]], dir = "IN_OUT", vm = true },
        { name = "iLOs to HSM ${upper(k)}", src = try([nsxt_policy_group.ilo[k].path], []), dst = [nsxt_policy_group.appliance[k].path], svc = [local.svc["https"], local.svc["tcp_3512"]], dir = "IN", vm = true },
        { name = "HSM ${upper(k)} to ESX hosts", src = [nsxt_policy_group.appliance[k].path], dst = h.hosts, svc = [local.svc["https"], local.svc["ssh"], local.svc["cim_https"]], dir = "IN_OUT", vm = true },
        { name = "Bastion to HSM ${upper(k)}", src = [var.bastion], dst = [nsxt_policy_group.appliance[k].path], svc = [local.svc["tcp_3512"]], dir = "IN", vm = true },
        ] : {
        display_name       = r.name
        source_groups      = r.src
        destination_groups = r.dst
        services           = r.svc
        direction          = r.dir
      }
      # An empty group list would mean "any".
      if length(r.src) > 0 && length(r.dst) > 0 && (!r.vm || h.vm_name != null)
    ]
  }
  rules = flatten([for k in sort(keys(var.hsms)) : local.rules_by_hsm[k]])
}

# The appliance, by exact VM name, IP addresses, or either.
resource "nsxt_policy_group" "appliance" {
  for_each = var.hsms

  nsx_id       = "HSM_${upper(each.key)}"
  display_name = "HSM_${upper(each.key)}"

  dynamic "criteria" {
    for_each = each.value.vm_name != null ? [each.value.vm_name] : []
    content {
      condition {
        member_type = "VirtualMachine"
        key         = "Name"
        operator    = "EQUALS"
        value       = criteria.value
      }
    }
  }

  dynamic "conjunction" {
    for_each = each.value.vm_name != null && length(each.value.ips) > 0 ? [1] : []
    content {
      operator = "OR"
    }
  }

  dynamic "criteria" {
    for_each = length(each.value.ips) > 0 ? [each.value.ips] : []
    content {
      ipaddress_expression {
        ip_addresses = criteria.value
      }
    }
  }
}

# The OneView appliances or Synergy Composers the appliance manages.
resource "nsxt_policy_group" "oneview" {
  for_each = { for k, h in var.hsms : k => h if length(h.oneview) > 0 }

  nsx_id       = "HSM_${upper(each.key)}_OV"
  display_name = "HSM_${upper(each.key)}_OV"
  group_type   = "IPAddress"

  criteria {
    ipaddress_expression {
      ip_addresses = each.value.oneview
    }
  }
}

# The iLOs the appliance manages.
resource "nsxt_policy_group" "ilo" {
  for_each = { for k, h in var.hsms : k => h if length(h.ilo) > 0 }

  nsx_id       = "HSM_${upper(each.key)}_ILO"
  display_name = "HSM_${upper(each.key)}_ILO"
  group_type   = "IPAddress"

  criteria {
    ipaddress_expression {
      ip_addresses = each.value.ilo
    }
  }
}
