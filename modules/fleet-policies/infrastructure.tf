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
    services           = [local.svc["dns_udp"], local.svc["dns_tcp"]]
    profiles           = [var.context_profile_paths.dns]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet NTP Traffic"
    destination_groups = [local.ext.ntp]
    services           = [local.svc["ntp"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet DHCP Traffic"
    destination_groups = [local.ext.dhcp]
    services           = [local.svc["dhcp_server"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name       = "VCF Fleet AD Traffic"
    destination_groups = [local.ext.ad]
    services           = [local.svc["ad"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  # VCF Management Services is included because log management runs there, and this category is
  # evaluated before the Environment policies that also allow it.
  rule {
    display_name       = "VCF Fleet Syslog Traffic"
    destination_groups = [local.ext.syslog, local.ext.siem, local.fleet.msvc]
    services           = [local.svc["syslog_tcp"], local.svc["syslog_udp"], local.svc["log_api"]]
    action             = "ALLOW"
    direction          = "OUT"
    logged             = false
  }

  rule {
    display_name = "VCF Fleet Infrastructure Lockdown"
    services = [
      local.svc["dns_udp"], local.svc["dns_tcp"], local.svc["ntp"], local.svc["dhcp_server"],
      local.svc["syslog_tcp"], local.svc["syslog_udp"], local.svc["log_api"],
    ]
    action    = var.lockdown_action
    direction = "OUT"
    logged    = true
    log_label = "infra"
  }
}
