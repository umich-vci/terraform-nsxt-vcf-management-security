# Ports used by the design that have no built-in NSX service, keyed by display name. TCP/5480 matches
# only the built-in "HBR Server App" (vSphere Replication), which would mislabel the rules, so it stays
# custom.
locals {
  custom_services = {
    "TCP-5480"        = { description = "Appliance management (VAMI)", protocol = "TCP", ports = ["5480"] }
    "TCP-6443"        = { description = "Kubernetes API", protocol = "TCP", ports = ["6443"] }
    "TCP-1514"        = { description = "Log management syslog over TLS", protocol = "TCP", ports = ["1514"] }
    "TCP-9543"        = { description = "Log management ingestion API (TLS)", protocol = "TCP", ports = ["9543"] }
    "TCP-4505_4506"   = { description = "VCF Management Services Salt", protocol = "TCP", ports = ["4505-4506"] }
    "TCP-1991"        = { description = "VCF Operations for Networks", protocol = "TCP", ports = ["1991"] }
    "UDP-2055"        = { description = "VCF Operations for Networks flows", protocol = "UDP", ports = ["2055"] }
    "TCP-9092"        = { description = "SSP / License Hub messaging", protocol = "TCP", ports = ["9092"] }
    "TCP-1443"        = { description = "vCenter IOFilter VASA provider", protocol = "TCP", ports = ["1443"] }
    "TCP-6500"        = { description = "ESX Dump Collector", protocol = "TCP", ports = ["6500"] }
    "TCP-6501_6502"   = { description = "vSphere Auto Deploy", protocol = "TCP", ports = ["6501-6502"] }
    "TCP-7475_7476"   = { description = "vSphere Authentication Proxy", protocol = "TCP", ports = ["7475-7476"] }
    "TCP-1234_1235"   = { description = "NSX transport node messaging", protocol = "TCP", ports = ["1234-1235"] }
    "TCP-5671"        = { description = "AMQP over TLS", protocol = "TCP", ports = ["5671"] }
    "TCP-8443"        = { description = "Avi controller and Service Engine management", protocol = "TCP", ports = ["8443"] }
    "TCP-30000_30005" = { description = "VCF Operations fleet management to VCF Automation", protocol = "TCP", ports = ["30000-30005"] }
    "TCP-3512"        = { description = "TCP-3512", protocol = "TCP", ports = ["3512"] }
  }
}

# Renamed from nsx_amqp: the service also carries HPE OneView SCMB.
moved {
  from = nsxt_policy_service.custom["nsx_amqp"]
  to   = nsxt_policy_service.custom["amqps"]
}

# Custom services were keyed by logical name before they were keyed by display name.

moved {
  from = nsxt_policy_service.custom["vami"]
  to   = nsxt_policy_service.custom["TCP-5480"]
}

moved {
  from = nsxt_policy_service.custom["k8s_api"]
  to   = nsxt_policy_service.custom["TCP-6443"]
}

moved {
  from = nsxt_policy_service.custom["syslog_tls"]
  to   = nsxt_policy_service.custom["TCP-1514"]
}

moved {
  from = nsxt_policy_service.custom["log_api"]
  to   = nsxt_policy_service.custom["TCP-9543"]
}

moved {
  from = nsxt_policy_service.custom["salt"]
  to   = nsxt_policy_service.custom["TCP-4505_4506"]
}

moved {
  from = nsxt_policy_service.custom["ops_networks"]
  to   = nsxt_policy_service.custom["TCP-1991"]
}

moved {
  from = nsxt_policy_service.custom["netflow"]
  to   = nsxt_policy_service.custom["UDP-2055"]
}

moved {
  from = nsxt_policy_service.custom["messaging"]
  to   = nsxt_policy_service.custom["TCP-9092"]
}

moved {
  from = nsxt_policy_service.custom["iofilter"]
  to   = nsxt_policy_service.custom["TCP-1443"]
}

moved {
  from = nsxt_policy_service.custom["dump_coll"]
  to   = nsxt_policy_service.custom["TCP-6500"]
}

moved {
  from = nsxt_policy_service.custom["auto_deploy"]
  to   = nsxt_policy_service.custom["TCP-6501_6502"]
}

moved {
  from = nsxt_policy_service.custom["auth_proxy"]
  to   = nsxt_policy_service.custom["TCP-7475_7476"]
}

moved {
  from = nsxt_policy_service.custom["nsx_rpc"]
  to   = nsxt_policy_service.custom["TCP-1234_1235"]
}

moved {
  from = nsxt_policy_service.custom["amqps"]
  to   = nsxt_policy_service.custom["TCP-5671"]
}

moved {
  from = nsxt_policy_service.custom["avi_mgmt"]
  to   = nsxt_policy_service.custom["TCP-8443"]
}

moved {
  from = nsxt_policy_service.custom["ops_lcm"]
  to   = nsxt_policy_service.custom["TCP-30000_30005"]
}

moved {
  from = nsxt_policy_service.custom["tcp_3512"]
  to   = nsxt_policy_service.custom["TCP-3512"]
}

resource "nsxt_policy_service" "custom" {
  for_each = local.custom_services

  display_name = each.key
  description  = each.value.description

  l4_port_set_entry {
    protocol          = each.value.protocol
    destination_ports = each.value.ports
  }

  # Without this, removing a service deletes it before the policies that still reference it are
  # updated, and NSX refuses the delete (error 500030).
  lifecycle {
    create_before_destroy = true
  }
}

# Every NSX service, built-in and custom, by display name. depends_on makes the lookup include the
# custom services above; when one of them changes, the lookup is read at apply time.
data "nsxt_policy_services" "all" {
  depends_on = [nsxt_policy_service.custom]
}

data "nsxt_policy_context_profile" "dns" {
  display_name = "DNS"
}

resource "nsxt_policy_context_profile_custom_attribute" "internet_fqdn" {
  for_each = toset(var.internet_fqdns)

  key       = "DOMAIN_NAME"
  attribute = each.value
}

resource "nsxt_policy_context_profile" "internet_fqdns" {
  display_name = "INTERNET_FQDNS"
  description  = "VCF depot, upgrade and patch downloads"

  domain_name {
    value = var.internet_fqdns
  }

  depends_on = [nsxt_policy_context_profile_custom_attribute.internet_fqdn]
}
