locals {
  fleet = var.fleet_group_paths
  ext   = var.external_group_paths

  zone_paths  = [for z in var.zones : z.zone]
  vc_paths    = distinct(flatten([for z in var.zones : z.vcs]))
  nsx_and_avi = distinct(flatten([for z in var.zones : z.nsx_and_avi]))
  sup_paths   = flatten([for z in var.zones : z.sups])

  msvc_services = [var.service_paths["HTTPS"], var.service_paths["TCP-4505_4506"], var.service_paths["Syslog (TCP)"], var.service_paths["Syslog (UDP)"], var.service_paths["TCP-1514"], var.service_paths["TCP-9543"]]
}

# All VCF fleet components (MDS-REQD-CFG-014). Hardware Support Managers are added so that the
# Infrastructure and Fleet rules also apply to them; that is not part of the design guide.
resource "nsxt_policy_group" "vcf_fleet" {
  nsx_id       = "VCF_FLEET"
  display_name = "VCF_FLEET"

  criteria {
    path_expression {
      member_paths = concat([local.fleet.vcf_fm], local.zone_paths, var.hsm_group_paths)
    }
  }
}
