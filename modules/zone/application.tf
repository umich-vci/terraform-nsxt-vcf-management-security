# Application-category ring-fencing for the zone's components, ported from the VCF 9.0 design
# (SEC-MD-CFG-035..041). Only intra-zone traffic reaches these: inter-zone traffic is decided by the
# Environment policies. Each policy governs ingress and egress of its members.

resource "nsxt_policy_security_policy" "vcenter" {
  for_each = var.domains

  display_name    = "${local.domain_titles[each.key]} vCenter Policy"
  description     = "${local.domain_titles[each.key]} vCenter Policy"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [each.value.vc]
  sequence_number = var.application_sequence_number + index(keys(var.domains), each.key)

  dynamic "rule" {
    for_each = each.value.hosts == null ? [] : [each.value.hosts]
    content {
      display_name       = "vCenter to Hosts"
      source_groups      = [each.value.vc]
      destination_groups = [rule.value]
      services           = [local.svc["update_mgr"], local.svc["icmp_all"], local.svc["iofilter"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = each.value.hosts == null ? [] : [each.value.hosts]
    content {
      display_name       = "Hosts to vCenter"
      source_groups      = [rule.value]
      destination_groups = [each.value.vc]
      services = [
        local.svc["https"], local.svc["vum"], local.svc["vum_update"], local.svc["esxi_udp"],
        local.svc["dump_coll"], local.svc["auto_deploy"], local.svc["auth_proxy"],
      ]
      action = "ALLOW"
      logged = false
    }
  }

  rule {
    display_name       = "${local.label} Appliance Management and Upgrade"
    source_groups      = [local.zone]
    destination_groups = [local.zone]
    services           = [local.svc["vami"], local.svc["vc_db"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "vCenter to NSX Manager"
    source_groups      = [each.value.vc]
    destination_groups = [local.c.nsx]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "NSX Manager to vCenter"
    source_groups      = [local.c.nsx]
    destination_groups = [each.value.vc]
    services           = [local.svc["https"], local.svc["http"], local.svc["vum_update"]]
    action             = "ALLOW"
    logged             = false
  }

  dynamic "rule" {
    for_each = local.c.avi == null ? [] : [local.c.avi]
    content {
      display_name       = "Avi to vCenter"
      source_groups      = [rule.value]
      destination_groups = [each.value.vc]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = local.c.ssp == null ? [] : [local.c.ssp]
    content {
      display_name       = "SSP to vCenter"
      source_groups      = [rule.value]
      destination_groups = [each.value.vc]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = each.value.sup == null ? [] : [each.value.sup]
    content {
      display_name       = "vCenter to Supervisor"
      source_groups      = [each.value.vc]
      destination_groups = [rule.value]
      services           = [local.svc["k8s_api"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = each.value.sup == null ? [] : [each.value.sup]
    content {
      display_name       = "Supervisor to vCenter"
      source_groups      = [rule.value]
      destination_groups = [each.value.vc]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  rule {
    display_name = "${local.domain_titles[each.key]} vCenter Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = substr(lower("app_${each.key}_vc"), 0, 32)
  }
}

# Not for the NSX Manager used by the management domain, which stays DFW-excluded (MDS-REQD-CFG-019).
resource "nsxt_policy_security_policy" "nsx" {
  count = var.nsx_dfw ? 1 : 0

  display_name    = "${local.title} NSX Manager Policy"
  description     = "${local.title} NSX Manager Policy"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.c.nsx]
  sequence_number = var.application_sequence_number + length(var.domains)

  rule {
    display_name       = "NSX Manager Cluster"
    source_groups      = [local.c.nsx]
    destination_groups = [local.c.nsx]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "NSX Transport Node Messaging"
    source_groups      = concat([local.c.nsx], local.hosts, local.edges)
    destination_groups = concat([local.c.nsx], local.hosts, local.edges)
    services           = [local.svc["https"], local.svc["nsx_rpc"], local.svc["nsx_amqp"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "vCenter to NSX Manager"
    source_groups      = local.vcs
    destination_groups = [local.c.nsx]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "NSX Manager to vCenter"
    source_groups      = [local.c.nsx]
    destination_groups = local.vcs
    services           = [local.svc["https"], local.svc["http"], local.svc["vum_update"]]
    action             = "ALLOW"
    logged             = false
  }

  dynamic "rule" {
    for_each = local.c.avi == null ? [] : [local.c.avi]
    content {
      display_name       = "Avi to NSX Manager"
      source_groups      = [rule.value]
      destination_groups = [local.c.nsx]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = local.c.ssp == null ? [] : [local.c.ssp]
    content {
      display_name       = "SSP to NSX Manager"
      source_groups      = [rule.value]
      destination_groups = [local.c.nsx]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  # Not in the 9.0 design: NSX Managers send metrics to the SSP ingress (9.1 SSP networking design).
  dynamic "rule" {
    for_each = local.c.ssp_svc == null ? [] : [local.c.ssp_svc]
    content {
      display_name       = "NSX Manager to SSP Ingestion"
      source_groups      = [local.c.nsx]
      destination_groups = [rule.value]
      services           = [local.svc["https"], local.svc["messaging"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = length(local.sups) > 0 ? [1] : []
    content {
      display_name       = "Supervisor to NSX Manager"
      source_groups      = local.sups
      destination_groups = [local.c.nsx]
      services           = [local.svc["https"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  rule {
    display_name = "${local.title} NSX Manager Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = substr(lower("app_${var.name}_nsx"), 0, 32)
  }
}

# Controllers only; Service Engines are protected on the controllers' side (SEC-MD-CFG-039).
resource "nsxt_policy_security_policy" "avi" {
  count = local.c.avi == null ? 0 : 1

  display_name    = "${local.title} Avi Load Balancer Policy"
  description     = "${local.title} Avi Load Balancer Policy"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.c.avi]
  sequence_number = var.application_sequence_number + length(var.domains) + 1

  rule {
    display_name       = "Avi Controller Cluster"
    source_groups      = [local.c.avi]
    destination_groups = [local.c.avi]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "Avi to ${local.label}"
    source_groups      = [local.c.avi]
    destination_groups = concat(local.vcs, [local.c.nsx], local.hosts)
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  dynamic "rule" {
    for_each = length(local.avi_ses) > 0 ? [1] : []
    content {
      display_name       = "Avi to and from Service Engine Management"
      source_groups      = concat([local.c.avi], local.avi_ses)
      destination_groups = concat([local.c.avi], local.avi_ses)
      services           = [local.svc["ssh"], local.svc["avi_mgmt"]]
      action             = "ALLOW"
      logged             = false
    }
  }

  rule {
    display_name = "${local.title} Avi Load Balancer Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = substr(lower("app_${var.name}_avi"), 0, 32)
  }
}

# Only for SSP VMs running in the management domain; elsewhere they are outside this DFW.
resource "nsxt_policy_security_policy" "ssp" {
  count = var.ssp_dfw ? 1 : 0

  display_name    = "${local.title} SSP Policy"
  description     = "${local.title} SSP Policy"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.c.ssp]
  sequence_number = var.application_sequence_number + length(var.domains) + 2

  rule {
    display_name       = "SSP to vCenter and NSX Manager"
    source_groups      = [local.c.ssp]
    destination_groups = concat(local.vcs, [local.c.nsx])
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "SSP Ingestion"
    source_groups      = concat([local.c.nsx], local.hosts, local.edges)
    destination_groups = [local.c.ssp_svc]
    services           = [local.svc["https"], local.svc["messaging"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "SSP Internal"
    source_groups      = [local.c.ssp]
    destination_groups = [local.c.ssp]
    action             = "ALLOW"
    logged             = false
  }

  # Reached through the Fleet policy's SSP jump; covers threat feeds and the SIEM.
  rule {
    display_name  = "SSP Feeds"
    source_groups = [local.c.ssp]
    services      = [local.svc["https"]]
    action        = "ALLOW"
    direction     = "OUT"
    logged        = false
  }

  rule {
    display_name = "${local.title} SSP Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = substr(lower("app_${var.name}_ssp"), 0, 32)
  }
}
