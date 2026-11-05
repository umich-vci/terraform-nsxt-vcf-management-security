resource "nsxt_policy_security_policy" "environment" {
  display_name    = "${local.label} Policy"
  description     = "${local.label} Policy"
  category        = "Environment"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.zone]
  sequence_number = var.sequence_number

  rule {
    display_name       = "${local.label} Intra-Environment"
    source_groups      = [local.zone]
    destination_groups = [local.zone]
    action             = "JUMP_TO_APPLICATION"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet Management to ${local.label}"
    source_groups      = [local.fleet.vcf_fm]
    destination_groups = [local.zone]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "SDDC Manager to ${local.label}"
    source_groups      = [local.fleet.sddc]
    destination_groups = [local.zone]
    services           = [local.svc["ssh"], local.svc["vami"], local.svc["icmp_echo"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} Components Backup to SDDC Manager"
    source_groups      = local.nsx_and_avi
    destination_groups = [local.fleet.sddc]
    services           = [local.svc["ssh"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations Cloud Proxy to ${local.label}"
    source_groups      = [local.fleet.ops_cp]
    destination_groups = [local.zone]
    services           = [local.svc["icmp_echo"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to VCF Management Services"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.msvc]
    services           = [local.svc["https"], local.svc["salt"], local.svc["syslog_tcp"], local.svc["syslog_udp"], local.svc["syslog_tls"], local.svc["log_api"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to VCF Operations for Networks"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.ops_net_cn]
    services           = [local.svc["https"], local.svc["ops_networks"], local.svc["netflow"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "${local.label} vCenter Servers to VCF License Server"
    source_groups      = local.vcs
    destination_groups = [local.fleet.license_server]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "vDefend License Hub to ${local.label}"
    source_groups      = [local.fleet.license_hub]
    destination_groups = [local.zone]
    services           = [local.svc["https"], local.svc["nfs"], local.svc["iscsi"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to vDefend License Hub"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.license_hub]
    services           = [local.svc["https"], local.svc["messaging"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "SSP Installer to ${local.label}"
    source_groups      = [local.fleet.ssp_installer]
    destination_groups = [local.zone]
    services           = [local.svc["https"], local.svc["k8s_api"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to SSP Installer Registry"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.ssp_installer]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name = "${local.label} Lockdown"
    action       = var.lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = substr(lower("${var.instance}_${var.name}"), 0, 32)
  }
}
