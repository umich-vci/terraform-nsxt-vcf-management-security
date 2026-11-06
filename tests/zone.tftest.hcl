# The zone module on its own: one zone for the domains sharing an NSX Manager, its Environment
# policy and its Application policies.

mock_provider "nsxt" {
  mock_resource "nsxt_policy_group" {
    defaults = { path = "/infra/domains/default/groups/VCF01_W01" }
  }
}

variables {
  name              = "w01"
  instance          = "VCF01"
  management_domain = "m01"
  domains = {
    w01 = {
      vc    = "/infra/domains/default/groups/W01_VC"
      hosts = "/infra/domains/default/groups/W01_HOSTS"
      edge  = "/infra/domains/default/groups/W01_EDGE"
      sup   = "/infra/domains/default/groups/W01_SUP"
    }
    w02 = {
      vc    = "/infra/domains/default/groups/W02_VC"
      hosts = "/infra/domains/default/groups/W02_HOSTS"
    }
  }
  cluster_group_paths = {
    nsx     = "/infra/domains/default/groups/W01_NSX"
    avi     = "/infra/domains/default/groups/W01_AVI"
    ssp     = "/infra/domains/default/groups/W01_SSP"
    ssp_svc = "/infra/domains/default/groups/W01_SSP_SVC"
  }
  nsx_dfw = true
  ssp_dfw = true
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
    "HTTPS"                   = "/infra/services/HTTPS"
    "HTTP"                    = "/infra/services/HTTP"
    "SSH"                     = "/infra/services/SSH"
    "ICMP ALL"                = "/infra/services/ICMP-ALL"
    "ICMP Echo Request"       = "/infra/services/ICMP-Echo"
    "TCP-5480"                = "/infra/services/TCP-5480"
    "TCP-4505_4506"           = "/infra/services/TCP-4505_4506"
    "Syslog (TCP)"            = "/infra/services/Syslog-TCP"
    "Syslog (UDP)"            = "/infra/services/Syslog-UDP"
    "TCP-1514"                = "/infra/services/TCP-1514"
    "TCP-9543"                = "/infra/services/TCP-9543"
    "TCP-1991"                = "/infra/services/TCP-1991"
    "UDP-2055"                = "/infra/services/UDP-2055"
    "NFS (TCP)"               = "/infra/services/NFS-TCP"
    "VMware-iSCSI-Server"     = "/infra/services/iSCSI"
    "TCP-9092"                = "/infra/services/TCP-9092"
    "TCP-6443"                = "/infra/services/TCP-6443"
    "Update Manager"          = "/infra/services/Update-Manager"
    "TCP-1443"                = "/infra/services/TCP-1443"
    "VMware-UpdateMgr-VUM"    = "/infra/services/VUM"
    "Vmware-UpdateMgr-update" = "/infra/services/VUM-update"
    "VMware-ESXi5.x-UDP"      = "/infra/services/ESXi-UDP"
    "TCP-6500"                = "/infra/services/TCP-6500"
    "TCP-6501_6502"           = "/infra/services/TCP-6501_6502"
    "TCP-7475_7476"           = "/infra/services/TCP-7475_7476"
    "TCP-1234_1235"           = "/infra/services/TCP-1234_1235"
    "TCP-5671"                = "/infra/services/TCP-5671"
    "TCP-8443"                = "/infra/services/TCP-8443"
  }
  sequence_number             = 4
  application_sequence_number = 110
  lockdown_action             = "ALLOW"
  application_lockdown_action = "DROP"
}

run "shared_nsx_zone_with_everything" {
  module {
    source = "./modules/zone"
  }

  assert {
    condition     = nsxt_policy_group.zone.nsx_id == "VCF01_W01" && nsxt_policy_security_policy.environment.display_name == "VCF01 Workload Domain W01 Policy" && nsxt_policy_security_policy.vcenter["w02"].display_name == "Workload Domain W02 vCenter Policy"
    error_message = "Both workload domains should form one zone named after the NSX Manager cluster."
  }
  assert {
    condition = toset(output.member_paths) == toset([
      "/infra/domains/default/groups/W01_VC", "/infra/domains/default/groups/W02_VC",
      "/infra/domains/default/groups/W01_NSX", "/infra/domains/default/groups/W01_AVI", "/infra/domains/default/groups/W01_SSP",
    ])
    error_message = "The zone should statically include both vCenters, the NSX Managers, Avi and the DFW-protected SSP."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.environment.rule) == 13 && nsxt_policy_security_policy.environment.rule[12].action == "ALLOW"
    error_message = "The zone Environment policy should have 13 rules and use lockdown_action."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.rule[7].source_groups == toset(["/infra/domains/default/groups/W01_VC", "/infra/domains/default/groups/W02_VC"])
    error_message = "Every vCenter in the zone should reach the License Server."
  }
  assert {
    condition     = keys(nsxt_policy_security_policy.vcenter) == ["w01", "w02"]
    error_message = "Each domain should get its own vCenter Application policy."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.vcenter["w01"].rule) == 9 && length(nsxt_policy_security_policy.vcenter["w02"].rule) == 7
    error_message = "vCenter policies should include host, Avi, SSP and (w01 only) Supervisor rules."
  }
  assert {
    condition     = alltrue([for p in values(nsxt_policy_security_policy.vcenter) : alltrue([for r in p.rule : !strcontains(r.display_name, "Appliance Management")])])
    error_message = "The zone-wide Appliance Management and Upgrade rule should be gone."
  }
  assert {
    condition = nsxt_policy_security_policy.nsx[0].rule[1].source_groups == toset([
      "/infra/domains/default/groups/W01_NSX", "/infra/domains/default/groups/W01_HOSTS", "/infra/domains/default/groups/W02_HOSTS",
      "/infra/domains/default/groups/W01_EDGE",
    ]) && nsxt_policy_security_policy.nsx[0].rule[1].services == toset(["/infra/services/HTTPS", "/infra/services/TCP-1234_1235", "/infra/services/TCP-5671"])
    error_message = "Hosts and edges of every domain in the zone should reach the shared NSX Manager."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.avi) == 1 && length(nsxt_policy_security_policy.ssp) == 1
    error_message = "Avi and the DFW-protected SSP should get Application policies."
  }
  assert {
    condition = alltrue([
      for p in concat(values(nsxt_policy_security_policy.vcenter), nsxt_policy_security_policy.nsx, nsxt_policy_security_policy.avi, nsxt_policy_security_policy.ssp) :
      p.category == "Application" && p.rule[length(p.rule) - 1].action == "DROP" && p.rule[length(p.rule) - 1].logged
    ])
    error_message = "Application lock-downs should use application_lockdown_action, independently of lockdown_action."
  }
}

run "display_name_differs_from_id" {
  module {
    source = "./modules/zone"
  }

  variables {
    display_name = "W01_W02"
  }

  assert {
    condition     = nsxt_policy_group.zone.nsx_id == "VCF01_W01" && nsxt_policy_group.zone.display_name == "VCF01_W01_W02"
    error_message = "The zone ID should use the cluster key and its display name the label."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.display_name == "VCF01 Workload Domain W01_W02 Policy" && nsxt_policy_security_policy.nsx[0].display_name == "Workload Domain W01_W02 NSX Manager Policy" && nsxt_policy_security_policy.avi[0].display_name == "Workload Domain W01_W02 Avi Load Balancer Policy"
    error_message = "Policy names should use the label."
  }
}

run "longest_names_fit_nsx_limits" {
  module {
    source = "./modules/zone"
  }

  variables {
    instance     = "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
    display_name = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
  }

  assert {
    condition = max(concat(
      [length(nsxt_policy_group.zone.display_name)],
      [for p in concat([nsxt_policy_security_policy.environment], values(nsxt_policy_security_policy.vcenter), nsxt_policy_security_policy.nsx, nsxt_policy_security_policy.avi, nsxt_policy_security_policy.ssp) : length(p.display_name)],
      flatten([for p in concat([nsxt_policy_security_policy.environment], values(nsxt_policy_security_policy.vcenter), nsxt_policy_security_policy.nsx, nsxt_policy_security_policy.avi, nsxt_policy_security_policy.ssp) : [for r in p.rule : length(r.display_name)]]),
    )...) <= 255
    error_message = "A display name exceeds NSX's 255-character limit."
  }
  assert {
    condition = alltrue(flatten([
      for p in concat([nsxt_policy_security_policy.environment], values(nsxt_policy_security_policy.vcenter), nsxt_policy_security_policy.nsx, nsxt_policy_security_policy.avi, nsxt_policy_security_policy.ssp) :
      [for r in p.rule : length(coalesce(r.log_label, "-")) <= 32]
    ]))
    error_message = "A log label exceeds NSX's 32-character limit."
  }
}

run "management_nsx_without_avi_or_ssp" {
  module {
    source = "./modules/zone"
  }

  variables {
    name = "m01"
    domains = {
      m01 = { vc = "/infra/domains/default/groups/M01_VC", hosts = "/infra/domains/default/groups/M01_HOSTS" }
    }
    cluster_group_paths = { nsx = "/infra/domains/default/groups/M01_NSX" }
    nsx_dfw             = false
    ssp_dfw             = false
  }

  assert {
    condition     = length(nsxt_policy_security_policy.nsx) == 0 && length(nsxt_policy_security_policy.avi) == 0 && length(nsxt_policy_security_policy.ssp) == 0
    error_message = "The DFW-excluded management NSX Manager, absent Avi and absent SSP get no Application policies."
  }
  assert {
    condition     = length(nsxt_policy_security_policy.vcenter["m01"].rule) == 5
    error_message = "Without Avi, SSP or Supervisors the vCenter policy has only its base rules."
  }
  assert {
    condition     = toset(output.member_paths) == toset(["/infra/domains/default/groups/M01_VC", "/infra/domains/default/groups/M01_NSX"])
    error_message = "The management zone should include its vCenter and NSX Managers."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.display_name == "VCF01 Management Domain Policy" && nsxt_policy_security_policy.vcenter["m01"].display_name == "Management Domain vCenter Policy"
    error_message = "Management domain zone policies should use the guide's names."
  }
  assert {
    condition     = nsxt_policy_security_policy.environment.rule[12].display_name == "VCF01 Management Domain Lockdown"
    error_message = "Lock-down rules should be named Lockdown."
  }
}
