# Application-category ring-fencing for the fleet management components, ported from the VCF 9.0
# design (SEC-MD-CFG-035..041) and adapted to 9.1: Ops for Logs and Ops fleet management are part of
# VCF Management Services. Only intra-zone (VCF_FM) traffic and explicit jumps reach these policies.

resource "nsxt_policy_security_policy" "vcf_operations" {
  display_name    = "VCF Operations Policy"
  description     = "VCF Operations, cloud proxies and SDDC Manager"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.fleet.ops, local.fleet.ops_cp, local.fleet.sddc]
  sequence_number = 1

  rule {
    display_name       = "VCF Operations Components"
    source_groups      = [local.fleet.ops, local.fleet.ops_cp, local.fleet.sddc]
    destination_groups = [local.fleet.ops, local.fleet.ops_cp, local.fleet.sddc]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations to VCF Automation and Operations for Networks"
    source_groups      = [local.fleet.ops]
    destination_groups = [local.fleet.vcf_a, local.fleet.ops_networks]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "VCF Operations Components to VCF Management Services"
    source_groups      = [local.fleet.ops, local.fleet.ops_cp, local.fleet.sddc]
    destination_groups = [local.fleet.msvc]
    services           = local.msvc_services
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "VCF Management Services to VCF Operations"
    source_groups      = [local.fleet.msvc]
    destination_groups = [local.fleet.ops]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name = "VCF Operations Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = "app_ops"
  }
}

resource "nsxt_policy_security_policy" "vcf_operations_networks" {
  count = var.ops_networks_enabled ? 1 : 0

  display_name    = "VCF Operations for Networks Policy"
  description     = "VCF Operations for Networks platform and collectors"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.fleet.ops_networks, local.fleet.ops_net_cn]
  sequence_number = 2

  rule {
    display_name       = "VCF Operations to Operations for Networks"
    source_groups      = [local.fleet.ops]
    destination_groups = [local.fleet.ops_networks]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "Operations for Networks Platform Cluster"
    source_groups      = [local.fleet.ops_networks]
    destination_groups = [local.fleet.ops_networks]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "Collectors to Operations for Networks Platform"
    source_groups      = [local.fleet.ops_net_cn]
    destination_groups = [local.fleet.ops_networks]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "Operations for Networks to VCF Management Services"
    source_groups      = [local.fleet.ops_networks, local.fleet.ops_net_cn]
    destination_groups = [local.fleet.msvc]
    services           = local.msvc_services
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name = "VCF Operations for Networks Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = "app_ops_net"
  }
}

# Also MDS-REQD-CFG-028: portal access through the native (and any external) load balancer.
resource "nsxt_policy_security_policy" "vcf_automation" {
  display_name    = "VCF Automation Policy"
  description     = "VCF Automation, including portal access through its load balancers"
  category        = "Application"
  locked          = false
  stateful        = true
  tcp_strict      = true
  scope           = [local.fleet.vcf_a]
  sequence_number = 3

  rule {
    display_name       = "VCF Operations to VCF Automation"
    source_groups      = [local.fleet.ops]
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    logged             = false
  }

  # 9.0 sourced this from the Ops fleet management appliance (VCF_OPS_FM); in 9.1 fleet management
  # runs on VCF Management Services.
  rule {
    display_name       = "VCF Operations Fleet Management to VCF Automation"
    source_groups      = [local.fleet.msvc]
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["ssh"], local.svc["https"], local.svc["k8s_api"], local.svc["ops_lcm"]]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "VCF Automation Cluster"
    source_groups      = [local.fleet.vcf_a]
    destination_groups = [local.fleet.vcf_a]
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name       = "Portal Access through Native Load Balancer"
    destination_groups = [local.fleet.vcf_a_nlb]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "Portal Access from External Load Balancer"
    source_groups      = [local.fleet.vcf_a_elb]
    destination_groups = [local.fleet.vcf_a]
    services           = [local.svc["https"]]
    action             = "ALLOW"
    direction          = "IN"
    logged             = false
  }

  rule {
    display_name       = "VCF Automation to VCF Management Services"
    source_groups      = [local.fleet.vcf_a]
    destination_groups = [local.fleet.msvc]
    services           = local.msvc_services
    action             = "ALLOW"
    logged             = false
  }

  rule {
    display_name = "VCF Automation Lockdown"
    action       = var.application_lockdown_action
    ip_version   = "IPV4_IPV6"
    logged       = true
    log_label    = "app_vcf_a"
  }
}
