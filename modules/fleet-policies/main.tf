locals {
  svc   = var.service_paths
  fleet = var.fleet_group_paths
  ext   = var.external_group_paths

  domain_paths = [for d in var.domains : d.domain]
  vc_paths     = distinct([for d in var.domains : d.vc])
  nsx_and_avi  = distinct(concat([for d in var.domains : d.nsx], [for d in var.domains : d.avi if d.avi != null]))
  sup_paths    = [for d in var.domains : d.sup if d.sup != null]

  msvc_services = [local.svc["https"], local.svc["salt"], local.svc["syslog_tcp"], local.svc["syslog_udp"], local.svc["syslog_tls"], local.svc["log_api"]]
}

# All VCF fleet components (MDS-REQD-CFG-014).
resource "nsxt_policy_group" "vcf_fleet" {
  nsx_id       = "VCF_FLEET"
  display_name = "VCF_FLEET"

  criteria {
    path_expression {
      member_paths = concat([local.fleet.vcf_fm], local.domain_paths)
    }
  }
}
