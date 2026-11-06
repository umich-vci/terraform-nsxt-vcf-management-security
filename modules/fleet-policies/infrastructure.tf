resource "nsxt_policy_security_policy" "infrastructure" {
  display_name    = "VCF Infrastructure Policy"
  description     = "VCF fleet access to infrastructure services"
  category        = "Infrastructure"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [nsxt_policy_group.vcf_fleet.path]
  sequence_number = 1

  rule {
    display_name       = "VCF Fleet DNS Traffic"
    destination_groups = [local.ext.dns]
    services           = [var.service_paths["DNS-UDP"], var.service_paths["DNS-TCP"]]
    profiles           = [var.context_profile_paths.dns]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet NTP Traffic"
    destination_groups = [local.ext.ntp]
    services           = [var.service_paths["NTP"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet DHCP Traffic"
    destination_groups = [local.ext.dhcp]
    services           = [var.service_paths["DHCP-Server"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet AD Traffic"
    destination_groups = [local.ext.ad]
    services           = [var.service_paths["Microsoft Active Directory V1"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  # VCF Management Services is included because log management runs there, and this category is
  # evaluated before the Environment policies that also allow it.
  rule {
    display_name       = "VCF Fleet Syslog Traffic"
    destination_groups = [local.ext.syslog, local.ext.siem, local.fleet.msvc]
    services           = [var.service_paths["Syslog (TCP)"], var.service_paths["Syslog (UDP)"], var.service_paths["TCP-9543"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name = "VCF Fleet Infrastructure Lockdown"
    services = [
      var.service_paths["DNS-UDP"], var.service_paths["DNS-TCP"], var.service_paths["NTP"], var.service_paths["DHCP-Server"],
      var.service_paths["Syslog (TCP)"], var.service_paths["Syslog (UDP)"], var.service_paths["TCP-9543"],
    ]
    action    = var.lockdown_action
    direction = "OUT"
    logged    = true
    log_label = "infra"
  }
}
