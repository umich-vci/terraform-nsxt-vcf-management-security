resource "nsxt_policy_security_policy" "fleet" {
  display_name    = "VCF Fleet Policy"
  description     = "VCF Fleet Policy"
  category        = "Environment"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [nsxt_policy_group.vcf_fleet.path]
  sequence_number = 1

  rule {
    display_name       = "Bastion to VCF Fleet"
    source_groups      = [local.ext.bastion]
    destination_groups = [nsxt_policy_group.vcf_fleet.path]
    services           = [var.service_paths["HTTPS"], var.service_paths["SSH"], var.service_paths["ICMP ALL"], var.service_paths["RDP"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "Tools to VCF Fleet"
    source_groups      = [local.ext.tools]
    destination_groups = [nsxt_policy_group.vcf_fleet.path]
    services           = [var.service_paths["HTTPS"], var.service_paths["SSH"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Automation Portal Access"
    destination_groups = [local.fleet.vcf_a]
    services           = [var.service_paths["HTTPS"]]
    action             = "JUMP_TO_APPLICATION"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Backup Traffic"
    source_groups      = [nsxt_policy_group.vcf_fleet.path]
    destination_groups = [local.ext.backup]
    services           = [var.service_paths["ICMP ALL"], var.service_paths["HTTPS"], var.service_paths["FTP"], var.service_paths["SSH"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Mail Server Traffic"
    source_groups      = [nsxt_policy_group.vcf_fleet.path]
    destination_groups = [local.ext.smtp]
    services           = [var.service_paths["SMTP"], var.service_paths["SMTP_TLS"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  # Not in the design guide's table: log management archives to NFS or S3 from the Management Services
  # nodes. ports.broadcom.com (Log Management 9.1) lists the flow, with S3 on TCP/8443; S3 endpoints
  # normally serve HTTPS on 443, which is what this rule allows.
  rule {
    display_name       = "Log Management Archive Traffic"
    source_groups      = [local.fleet.msvc]
    destination_groups = [local.ext.log_archive]
    services           = [var.service_paths["NFS (TCP)"], var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name  = "Broadcom Depot Traffic"
    source_groups = [nsxt_policy_group.vcf_fleet.path]
    services      = [var.service_paths["HTTPS"]]
    profiles      = [var.context_profile_paths.internet_fqdns]
    action        = "ALLOW"
    direction     = "OUT"
    logged        = false
  }

  # Not in the design guide: vSphere Lifecycle Manager Hardware Support Managers, from the HSM vendor
  # modules. The appliances are in VCF_FLEET, so these rules apply at the vCenters and at an appliance
  # VM, ahead of the zone policies. Rules with an empty side are skipped (an empty list means any).
  dynamic "rule" {
    for_each = [for r in var.hsm_rules : r if length(r.source_groups) > 0 && length(r.destination_groups) > 0 && length(r.services) > 0]
    content {
      display_name       = rule.value.display_name
      source_groups      = rule.value.source_groups
      destination_groups = rule.value.destination_groups
      services           = rule.value.services
      action             = "ALLOW"
      direction          = rule.value.direction
      logged             = false
    }
  }

  # SSP threat feeds and SIEM have an Any destination, so they jump to the SSP Application policy
  # instead of hitting the zone lock-down.
  dynamic "rule" {
    for_each = length(var.dfw_ssp_paths) > 0 ? [1] : []
    content {
      display_name  = "SSP Feeds"
      source_groups = var.dfw_ssp_paths
      services      = [var.service_paths["HTTPS"]]
      action        = "JUMP_TO_APPLICATION"
      direction     = "OUT"
      logged        = false
    }
  }
}

resource "nsxt_policy_security_policy" "fleet_management" {
  display_name    = "VCF Fleet Management Policy"
  description     = "VCF Fleet Management Policy"
  category        = "Environment"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.fleet.vcf_fm]
  sequence_number = 2

  rule {
    display_name       = "VCF Fleet Management Intra-Environment"
    source_groups      = [local.fleet.vcf_fm]
    destination_groups = [local.fleet.vcf_fm]
    action             = "JUMP_TO_APPLICATION"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Management to VCF Domains"
    source_groups      = [local.fleet.vcf_fm]
    destination_groups = local.zone_paths
    services           = [var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "SDDC Manager to VCF Domains"
    source_groups      = [local.fleet.sddc]
    destination_groups = local.zone_paths
    services           = [var.service_paths["SSH"], var.service_paths["TCP-5480"], var.service_paths["ICMP Echo Request"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "Components Backup to SDDC Manager"
    source_groups      = local.nsx_and_avi
    destination_groups = [local.fleet.sddc]
    services           = [var.service_paths["SSH"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations Cloud Proxy to VCF Domains"
    source_groups      = [local.fleet.ops_cp]
    destination_groups = concat([local.fleet.vcf_fm], local.zone_paths)
    services           = [var.service_paths["ICMP Echo Request"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to VCF Management Services"
    source_groups      = local.zone_paths
    destination_groups = [local.fleet.msvc]
    services           = local.msvc_services
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to VCF Operations for Networks"
    source_groups      = local.zone_paths
    destination_groups = [local.fleet.ops_net_cn]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-1991"], var.service_paths["UDP-2055"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  # Skipped without Supervisors: an empty group list would mean "any".
  dynamic "rule" {
    for_each = length(local.sup_paths) > 0 ? [1] : []
    content {
      display_name       = "Supervisors to VCF Automation and Cloud Proxy"
      source_groups      = local.sup_paths
      destination_groups = [local.fleet.vcf_a, local.fleet.ops_cp]
      services           = [var.service_paths["HTTPS"]]
      action             = "ALLOW"
      direction          = "IN"
      logged             = false
    }
  }

  dynamic "rule" {
    for_each = length(local.sup_paths) > 0 ? [1] : []
    content {
      display_name       = "VCF Automation to Supervisors"
      source_groups      = [local.fleet.vcf_a]
      destination_groups = local.sup_paths
      services           = [var.service_paths["TCP-6443"]]
      action             = "ALLOW"
      direction          = "OUT"
      logged             = false
    }
  }

  rule {
    display_name       = "vCenter Servers to VCF License Server"
    source_groups      = local.vc_paths
    destination_groups = [local.fleet.license_server]
    services           = [var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "vDefend License Hub to VCF Domains"
    source_groups      = [local.fleet.license_hub]
    destination_groups = local.zone_paths
    services           = [var.service_paths["HTTPS"], var.service_paths["NFS (TCP)"], var.service_paths["VMware-iSCSI-Server"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to vDefend License Hub"
    source_groups      = local.zone_paths
    destination_groups = [local.fleet.license_hub]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-9092"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "SSP Installer to VCF Domains"
    source_groups      = [local.fleet.ssp_installer]
    destination_groups = local.zone_paths
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-6443"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to SSP Installer Registry"
    source_groups      = local.zone_paths
    destination_groups = [local.fleet.ssp_installer]
    services           = [var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name = "VCF Fleet Management Lockdown"
    action       = var.lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = "vcf_fm"
  }
}
