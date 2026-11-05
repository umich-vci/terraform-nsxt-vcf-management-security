# The fleet-policies module on its own: fleet-level Environment, Infrastructure and Application policies.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/VCF_FLEET" }
  }
}

variables {
  zones = {
    m01 = {
      zone        = "/infra/domains/default/groups/VCF01_M01"
      vcs         = ["/infra/domains/default/groups/M01_VC"]
      nsx_and_avi = ["/infra/domains/default/groups/M01_NSX"]
      sups        = []
    }
    w01 = {
      zone        = "/infra/domains/default/groups/VCF01_W01"
      vcs         = ["/infra/domains/default/groups/W01_VC", "/infra/domains/default/groups/W02_VC"]
      nsx_and_avi = ["/infra/domains/default/groups/W01_NSX"]
      sups        = []
    }
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
    vcf_a_nlb      = "/infra/domains/default/groups/VCF_A_NLB"
    vcf_a_elb      = "/infra/domains/default/groups/VCF_A_ELB"
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
    ops_networks = "/infra/services/TCP-1991", netflow = "/infra/services/UDP-2055", nfs = "/infra/services/NFS-TCP",
    iscsi        = "/infra/services/iSCSI", messaging = "/infra/services/TCP-9092", k8s_api = "/infra/services/TCP-6443",
    ops_lcm      = "/infra/services/TCP-30000_30005"
  }
  context_profile_paths = {
    dns            = "/infra/context-profiles/DNS"
    internet_fqdns = "/infra/context-profiles/INTERNET_FQDNS"
  }
  lockdown_action             = "ALLOW"
  application_lockdown_action = "ALLOW"
}

run "defaults" {
  module {
    source = "./modules/fleet-policies"
  }

  assert {
    condition     = length(nsxt_policy_security_policy.fleet_management.rule) == 13
    error_message = "Without Supervisors the two Supervisor rules are skipped."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[1].destination_groups == toset(["/infra/domains/default/groups/VCF01_M01", "/infra/domains/default/groups/VCF01_W01"])
    error_message = "Fleet Management rules should target the zone groups."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[7].source_groups == toset(["/infra/domains/default/groups/M01_VC", "/infra/domains/default/groups/W01_VC", "/infra/domains/default/groups/W02_VC"])
    error_message = "Every vCenter should reach the License Server."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.fleet.rule) == 7
    error_message = "Without a DFW-protected SSP the Fleet policy has no SSP feeds jump."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.vcf_operations_networks) == 0
    error_message = "No Ops for Networks policy without Ops for Networks."
  }
  assert {
    condition     = nsxt_policy_security_policy.vcf_automation.rule[1].source_groups == toset(["/infra/domains/default/groups/VCF01_MSVC"]) && nsxt_policy_security_policy.vcf_automation.rule[1].services == toset(["/infra/services/SSH", "/infra/services/HTTPS", "/infra/services/TCP-6443", "/infra/services/TCP-30000_30005"])
    error_message = "Fleet management access to VCF Automation should default to VCF Management Services."
  }
  assert {
    condition = alltrue([
      for p in [nsxt_policy_security_policy.vcf_operations, nsxt_policy_security_policy.vcf_automation] :
      p.category == "Application" && p.rule[length(p.rule) - 1].action == "ALLOW" && p.rule[length(p.rule) - 1].ip_version == "IPV4_IPV6"
    ])
    error_message = "Application lock-downs should allow and log by default."
  }
  assert {
    condition     = nsxt_policy_security_policy.infrastructure.rule[4].destination_groups == toset(["/infra/domains/default/groups/SYSLOG_SVC", "/infra/domains/default/groups/SIEM_SVC", "/infra/domains/default/groups/VCF01_MSVC"])
    error_message = "Syslog should be allowed to the syslog servers, the SIEM and VCF Management Services."
  }
}

run "everything_enabled" {
  module {
    source = "./modules/fleet-policies"
  }

  variables {
    zones = {
      w01 = {
        zone        = "/infra/domains/default/groups/VCF01_W01"
        vcs         = ["/infra/domains/default/groups/W01_VC"]
        nsx_and_avi = ["/infra/domains/default/groups/W01_NSX", "/infra/domains/default/groups/W01_AVI"]
        sups        = ["/infra/domains/default/groups/W01_SUP"]
      }
    }
    dfw_ssp_paths        = ["/infra/domains/default/groups/W01_SSP"]
    ops_networks_enabled = true
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
      vcf_a_nlb      = "/infra/domains/default/groups/VCF_A_NLB"
      vcf_a_elb      = "/infra/domains/default/groups/VCF_A_ELB"
    }
    lockdown_action             = "DROP"
    application_lockdown_action = "ALLOW"
  }

  assert {
    condition     = length(nsxt_policy_security_policy.fleet_management.rule) == 15 && nsxt_policy_security_policy.fleet_management.rule[7].source_groups == toset(["/infra/domains/default/groups/W01_SUP"])
    error_message = "With Supervisors both Supervisor rules are present."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet.rule[7].action == "JUMP_TO_APPLICATION" && nsxt_policy_security_policy.fleet.rule[7].source_groups == toset(["/infra/domains/default/groups/W01_SSP"])
    error_message = "A DFW-protected SSP should jump to Application for its feeds."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.vcf_operations_networks) == 1
    error_message = "Ops for Networks should get its Application policy."
  }
  assert {
    condition     = nsxt_policy_security_policy.fleet_management.rule[14].action == "DROP" && nsxt_policy_security_policy.vcf_automation.rule[6].action == "ALLOW"
    error_message = "lockdown_action and application_lockdown_action should be independent."
  }
}
