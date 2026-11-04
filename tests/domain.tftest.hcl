# The domain module on its own: group names, membership and the Environment policy.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/MOCK" }
  }
}

variables {
  name           = "w01"
  instance       = "VCF01"
  vcenter_prefix = "w01-vc01"
  hosts          = ["203.0.113.0/28"]
  cluster_group_paths = {
    nsx = "/infra/domains/default/groups/W01_NSX"
  }
  fleet_group_paths = {
    vcf_fm         = "/infra/domains/default/groups/VCF_FM"
    sddc           = "/infra/domains/default/groups/VCF01_SDDC"
    ops_cp         = "/infra/domains/default/groups/VCF01_OPS_CP"
    msvc           = "/infra/domains/default/groups/VCF01_MSVC"
    ops_net_cn     = "/infra/domains/default/groups/VCF01_OPS_NET_CN"
    license_server = "/infra/domains/default/groups/VCF01_LIC"
    license_hub    = "/infra/domains/default/groups/VCF01_LHUB"
    ssp_installer  = "/infra/domains/default/groups/VCF01_SSPI01"
  }
  service_paths = {
    https        = "/infra/services/HTTPS", ssh = "/infra/services/SSH", icmp_echo = "/infra/services/ICMP-Echo",
    vami         = "/infra/services/TCP-5480", salt = "/infra/services/TCP-4505_4506", syslog_tcp = "/infra/services/Syslog-TCP",
    syslog_udp   = "/infra/services/Syslog-UDP", syslog_tls = "/infra/services/TCP-1514", log_api = "/infra/services/TCP-9543",
    ops_networks = "/infra/services/TCP-1991", netflow = "/infra/services/UDP-2055", nfs = "/infra/services/TCP-2049",
    iscsi        = "/infra/services/TCP-3260", messaging = "/infra/services/TCP-9092", k8s_api = "/infra/services/TCP-6443"
  }
  sequence_number = 4
  lockdown_action = "ALLOW"
}

run "minimal_domain" {
  module {
    source = "./modules/domain"
  }

  assert {
    condition     = nsxt_policy_group.domain.nsx_id == "VCF01_W01" && nsxt_policy_group.vc.nsx_id == "W01_VC"
    error_message = "Unexpected group names."
  }
  assert {
    condition     = keys(nsxt_policy_group.ip) == ["hosts"] && nsxt_policy_group.ip["hosts"].nsx_id == "W01_HOSTS"
    error_message = "Only the hosts IP group should exist when the other lists are empty."
  }
  assert {
    condition     = length(output.member_paths) == 2 && contains(output.member_paths, "/infra/domains/default/groups/W01_NSX")
    error_message = "Static members should be the vCenter and NSX Manager groups."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.environment.rule) == 13
    error_message = "The domain policy should have the 13 rules of the design guide."
  }
  assert {
    condition = (
      nsxt_policy_security_policy.environment.rule[12].action == "ALLOW" &&
      nsxt_policy_security_policy.environment.rule[12].ip_version == "IPV4_IPV6" &&
      nsxt_policy_security_policy.environment.rule[12].log_label == "vcf01_w01"
    )
    error_message = "The lock-down rule should allow and log IPv4 and IPv6 by default."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.rule[3].source_groups == toset(["/infra/domains/default/groups/W01_NSX"])
    error_message = "Without Avi only the NSX Managers back up to SDDC Manager."
  }
}

run "full_domain" {
  module {
    source = "./modules/domain"
  }

  variables {
    edges               = ["203.0.113.16/28"]
    supervisors         = ["203.0.113.64/28"]
    avi_service_engines = ["203.0.113.96/28"]
    ip_storage          = ["203.0.113.128/28"]
    cluster_group_paths = {
      nsx = "/infra/domains/default/groups/W01_NSX"
      avi = "/infra/domains/default/groups/W01_AVI"
    }
    hosted_ssp_paths = ["/infra/domains/default/groups/W01_SSP"]
    lockdown_action  = "DROP"
  }

  assert {
    condition     = toset([for g in nsxt_policy_group.ip : g.nsx_id]) == toset(["W01_HOSTS", "W01_EDGE", "W01_SUP", "W01_AVI_SE", "W01_STORAGE"])
    error_message = "All IP groups should exist."
  }
  assert {
    condition     = alltrue([for g in nsxt_policy_group.ip : one(g.tag).scope == "w01"])
    error_message = "IP groups should carry the domain as tag scope."
  }
  assert {
    condition     = length(output.member_paths) == 4 && contains(output.member_paths, "/infra/domains/default/groups/W01_AVI") && contains(output.member_paths, "/infra/domains/default/groups/W01_SSP")
    error_message = "Avi controllers and the hosted SSP should be statically included."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.rule[3].source_groups == toset(["/infra/domains/default/groups/W01_NSX", "/infra/domains/default/groups/W01_AVI"])
    error_message = "With Avi, the controllers also back up to SDDC Manager."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.rule[12].action == "DROP"
    error_message = "lockdown_action should set the lock-down action."
  }
}
