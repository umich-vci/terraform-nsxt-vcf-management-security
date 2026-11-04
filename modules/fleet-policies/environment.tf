resource "nsxt_policy_security_policy" "fleet" {
  display_name    = "VCF Fleet Environment"
  description     = "VCF Fleet Environment"
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
    services           = [local.svc["https"], local.svc["ssh"], local.svc["icmp_all"], local.svc["rdp"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "Tools to VCF Fleet"
    source_groups      = [local.ext.tools]
    destination_groups = [nsxt_policy_group.vcf_fleet.path]
    services           = [local.svc["https"], local.svc["ssh"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Automation Portal Access"
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["https"]]
    action             = "JUMP_TO_APPLICATION"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Backup Traffic"
    source_groups      = [nsxt_policy_group.vcf_fleet.path]
    destination_groups = [local.ext.backup]
    services           = [local.svc["icmp_all"], local.svc["https"], local.svc["ftp"], local.svc["ssh"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Mail Server Traffic"
    source_groups      = [nsxt_policy_group.vcf_fleet.path]
    destination_groups = [local.ext.smtp]
    services           = [local.svc["smtp"], local.svc["smtp_tls"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  # Not in the design guide's table: log management archives to NFS or S3 from the Management Services nodes.
  rule {
    display_name       = "Log Management Archive Traffic"
    source_groups      = [local.fleet.msvc]
    destination_groups = [local.ext.log_archive]
    services           = [local.svc["nfs"], local.svc["https"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name  = "Broadcom Depot Traffic"
    source_groups = [nsxt_policy_group.vcf_fleet.path]
    services      = [local.svc["https"]]
    profiles      = [var.context_profile_paths.internet_fqdns]
    action        = "ALLOW"
    direction     = "OUT"
    logged        = false
  }
}

resource "nsxt_policy_security_policy" "fleet_management" {
  display_name    = "VCF Fleet Management Environment"
  description     = "VCF Fleet Management Environment"
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
    destination_groups = local.domain_paths
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "SDDC Manager to VCF Domains"
    source_groups      = [local.fleet.sddc]
    destination_groups = local.domain_paths
    services           = [local.svc["ssh"], local.svc["vami"], local.svc["icmp_echo"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "Components Backup to SDDC Manager"
    source_groups      = local.nsx_and_avi
    destination_groups = [local.fleet.sddc]
    services           = [local.svc["ssh"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations Cloud Proxy to VCF Domains"
    source_groups      = [local.fleet.ops_cp]
    destination_groups = concat([local.fleet.vcf_fm], local.domain_paths)
    services           = [local.svc["icmp_echo"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to VCF Management Services"
    source_groups      = local.domain_paths
    destination_groups = [local.fleet.msvc]
    services           = local.msvc_services
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to VCF Operations for Networks"
    source_groups      = local.domain_paths
    destination_groups = [local.fleet.ops_net_cn]
    services           = [local.svc["https"], local.svc["ops_networks"], local.svc["netflow"]]
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
      services           = [local.svc["https"]]
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
      services           = [local.svc["k8s_api"]]
      action             = "ALLOW"
      direction          = "OUT"
      logged             = false
    }
  }

  rule {
    display_name       = "vCenter Servers to VCF License Server"
    source_groups      = local.vc_paths
    destination_groups = [local.fleet.license_server]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "vDefend License Hub to VCF Domains"
    source_groups      = [local.fleet.license_hub]
    destination_groups = local.domain_paths
    services           = [local.svc["https"], local.svc["nfs"], local.svc["iscsi"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to vDefend License Hub"
    source_groups      = local.domain_paths
    destination_groups = [local.fleet.license_hub]
    services           = [local.svc["https"], local.svc["messaging"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "SSP Installer to VCF Domains"
    source_groups      = [local.fleet.ssp_installer]
    destination_groups = local.domain_paths
    services           = [local.svc["https"], local.svc["k8s_api"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Domains to SSP Installer Registry"
    source_groups      = local.domain_paths
    destination_groups = [local.fleet.ssp_installer]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name = "VCF Fleet Management Lock Down"
    action       = var.lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = "vcf_fm"
  }
}
