# MDS-REQD-CFG-028: VCF Automation portal access. Users outside the fleet reach VCF Automation only
# through its native load balancer (or an external one); fleet-internal HTTPS is left alone.
resource "nsxt_policy_security_policy" "vcf_automation" {
  display_name    = "VCF Automation Portal Access"
  description     = "VCF Automation portal access through its load balancers"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.fleet.vcf_a]
  sequence_number = 1

  rule {
    display_name       = "Portal Access through Native Load Balancer"
    destination_groups = [local.fleet.vcf_a_lb]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "Portal Access from External Load Balancer"
    source_groups      = [local.fleet.vcf_a_ext_lb]
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "Direct Portal Access Lock Down"
    source_groups      = [nsxt_policy_group.vcf_fleet.path]
    sources_excluded   = true
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["https"]]
    action             = var.lockdown_action
    direction          = "IN"
    logged             = true
    log_label          = "vcf_a"
  }
}
