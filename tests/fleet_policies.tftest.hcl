# The fleet-policies module on its own: rule sets of the fleet-level policies.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/VCF_FLEET" }
  }
}

variables {
  domains = {
    m01 = { domain = "/infra/domains/default/groups/VCF01_M01", vc = "/infra/domains/default/groups/M01_VC", nsx = "/infra/domains/default/groups/M01_NSX" }
    w01 = { domain = "/infra/domains/default/groups/VCF01_W01", vc = "/infra/domains/default/groups/W01_VC", nsx = "/infra/domains/default/groups/W01_NSX" }
    w02 = { domain = "/infra/domains/default/groups/VCF01_W02", vc = "/infra/domains/default/groups/W02_VC", nsx = "/infra/domains/default/groups/W01_NSX" }
  }
  fleet_group_paths = {
    vcf_fm         = "/infra/domains/default/groups/VCF_FM"
    ops            = "/infra/domains/default/groups/VCF_OPS"
    ops_networks   = "/infra/domains/default/groups/VCF_OPS_NET"
    sddc           = "/infra/domains/default/groups/VCF01_SDDC"
    license_server = "/infra/domains/default/groups/VCF01_LIC"
    license_hub    = "/infra/domains/default/groups/VCF01_LHUB"
    ssp_installer  = "/infra/domains/default/groups/VCF01_SSPI01"
    ops_cp         = "/infra/domains/default/groups/VCF01_OPS_CP"
    ops_net_cn     = "/infra/domains/default/groups/VCF01_OPS_NET_CN"
    vcf_a          = "/infra/domains/default/groups/VCF_A"
    msvc           = "/infra/domains/default/groups/VCF01_MSVC"
    vcf_a_lb       = "/infra/domains/default/groups/VCF_A_LB"
    vcf_a_ext_lb   = "/infra/domains/default/groups/VCF_A_EXT_LB"
  }
  external_group_paths = {
    bastion     = "/infra/domains/default/groups/BASTION"
    tools       = "/infra/domains/default/groups/TOOLS"
    backup      = "/infra/domains/default/groups/BACKUP_SVC"
    smtp        = "/infra/domains/default/groups/SMTP_SVC"
    siem        = "/infra/domains/default/groups/SIEM_SVC"
    dns         = "/infra/domains/default/groups/DNS_SVC"
    ntp         = "/infra/domains/default/groups/NTP_SVC"
    dhcp        = "/infra/domains/default/groups/DHCP_SVC"
    ad          = "/infra/domains/default/groups/AD_SVC"
    syslog      = "/infra/domains/default/groups/SYSLOG_SVC"
    log_archive = "/infra/domains/default/groups/LOG_ARCHIVE_SVC"
  }
  service_paths = {
    https        = "/infra/services/HTTPS", ssh = "/infra/services/SSH", rdp = "/infra/services/RDP", ftp = "/infra/services/FTP",
    icmp_all     = "/infra/services/ICMP-ALL", icmp_echo = "/infra/services/ICMP-Echo", smtp = "/infra/services/SMTP",
    smtp_tls     = "/infra/services/SMTP_TLS", dns_tcp = "/infra/services/DNS-TCP", dns_udp = "/infra/services/DNS-UDP",
    ntp          = "/infra/services/NTP", dhcp_server = "/infra/services/DHCP-Server", ad = "/infra/services/AD",
    syslog_tcp   = "/infra/services/Syslog-TCP", syslog_udp = "/infra/services/Syslog-UDP", vami = "/infra/services/TCP-5480",
    salt         = "/infra/services/TCP-4505_4506", syslog_tls = "/infra/services/TCP-1514", log_api = "/infra/services/TCP-9543",
    ops_networks = "/infra/services/TCP-1991", netflow = "/infra/services/UDP-2055", nfs = "/infra/services/TCP-2049",
    iscsi        = "/infra/services/TCP-3260", messaging = "/infra/services/TCP-9092", k8s_api = "/infra/services/TCP-6443"
  }
  context_profile_paths = {
    dns            = "/infra/context-profiles/DNS"
    internet_fqdns = "/infra/context-profiles/INTERNET_FQDNS"
  }
  lockdown_action = "ALLOW"
}

run "without_supervisors" {
  module {
    source = "./modules/fleet-policies"
  }

  assert {
    condition     = length(nsxt_policy_security_policy.fleet_management.rule) == 13
    error_message = "Without Supervisors the two Supervisor rules are skipped."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[3].source_groups == toset(["/infra/domains/default/groups/M01_NSX", "/infra/domains/default/groups/W01_NSX"])
    error_message = "A shared NSX Manager group should appear once in the backup rule."
  }
  assert {
    condition = alltrue([
      for p in [nsxt_policy_security_policy.fleet_management, nsxt_policy_security_policy.infrastructure] :
      p.rule[length(p.rule) - 1].action == "ALLOW" && p.rule[length(p.rule) - 1].logged
    ])
    error_message = "Lock-downs should allow and log by default."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[12].ip_version == "IPV4_IPV6"
    error_message = "The Fleet Management lock-down should cover IPv4 and IPv6."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.fleet.rule) == 7 && nsxt_policy_security_policy.fleet.rule[3].services == toset(["/infra/services/ICMP-ALL", "/infra/services/HTTPS", "/infra/services/FTP", "/infra/services/SSH"])
    error_message = "The Fleet policy should include HTTPS to the backup servers."
  }
  assert {
    condition     = nsxt_policy_security_policy.infrastructure.rule[4].destination_groups == toset(["/infra/domains/default/groups/SYSLOG_SVC", "/infra/domains/default/groups/SIEM_SVC", "/infra/domains/default/groups/VCF01_MSVC"])
    error_message = "Syslog should be allowed to the syslog servers, the SIEM and VCF Management Services."
  }
  assert {
    condition     = nsxt_policy_security_policy.vcf_automation.category == "Application" && nsxt_policy_security_policy.vcf_automation.rule[2].sources_excluded
    error_message = "The VCF Automation lock-down should apply to sources outside VCF_FLEET."
  }
}

run "with_supervisors" {
  module {
    source = "./modules/fleet-policies"
  }

  variables {
    lockdown_action = "DROP"
    domains = {
      m01 = { domain = "/infra/domains/default/groups/VCF01_M01", vc = "/infra/domains/default/groups/M01_VC", nsx = "/infra/domains/default/groups/M01_NSX" }
      w01 = { domain = "/infra/domains/default/groups/VCF01_W01", vc = "/infra/domains/default/groups/W01_VC", nsx = "/infra/domains/default/groups/W01_NSX", avi = "/infra/domains/default/groups/W01_AVI", sup = "/infra/domains/default/groups/W01_SUP" }
    }
  }

  assert {
    condition     = length(nsxt_policy_security_policy.fleet_management.rule) == 15
    error_message = "With Supervisors both Supervisor rules are present."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[7].source_groups == toset(["/infra/domains/default/groups/W01_SUP"])
    error_message = "The Supervisor rule should source the Supervisor groups."
  }
  assert {
    condition     = contains(nsxt_policy_security_policy.fleet_management.rule[3].source_groups, "/infra/domains/default/groups/W01_AVI")
    error_message = "Avi controllers back up to SDDC Manager."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[14].action == "DROP" && nsxt_policy_security_policy.vcf_automation.rule[2].action == "DROP"
    error_message = "lockdown_action should set every lock-down."
  }
}
