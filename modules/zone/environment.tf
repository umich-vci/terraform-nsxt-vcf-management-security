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
    services           = [var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "SDDC Manager to ${local.label}"
    source_groups      = [local.fleet.sddc]
    destination_groups = [local.zone]
    services           = [var.service_paths["SSH"], var.service_paths["TCP-5480"], var.service_paths["ICMP Echo Request"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} Components Backup to SDDC Manager"
    source_groups      = local.nsx_and_avi
    destination_groups = [local.fleet.sddc]
    services           = [var.service_paths["SSH"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations Cloud Proxy to ${local.label}"
    source_groups      = [local.fleet.ops_cp]
    destination_groups = [local.zone]
    services           = [var.service_paths["ICMP Echo Request"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to VCF Management Services"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.msvc]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-4505_4506"], var.service_paths["Syslog (TCP)"], var.service_paths["Syslog (UDP)"], var.service_paths["TCP-1514"], var.service_paths["TCP-9543"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to VCF Operations for Networks"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.ops_net_cn]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-1991"], var.service_paths["UDP-2055"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "${local.label} vCenter Servers to VCF License Server"
    source_groups      = local.vcs
    destination_groups = [local.fleet.license_server]
    services           = [var.service_paths["HTTPS"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "vDefend License Hub to ${local.label}"
    source_groups      = [local.fleet.license_hub]
    destination_groups = [local.zone]
    services           = [var.service_paths["HTTPS"], var.service_paths["NFS (TCP)"], var.service_paths["VMware-iSCSI-Server"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to vDefend License Hub"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.license_hub]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-9092"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "SSP Installer to ${local.label}"
    source_groups      = [local.fleet.ssp_installer]
    destination_groups = [local.zone]
    services           = [var.service_paths["HTTPS"], var.service_paths["TCP-6443"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "${local.label} to SSP Installer Registry"
    source_groups      = [local.zone]
    destination_groups = [local.fleet.ssp_installer]
    services           = [var.service_paths["HTTPS"]]
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
