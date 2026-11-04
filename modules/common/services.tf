data "nsxt_policy_services" "all" {}

locals {
  # Built-in NSX services, by the display name NSX ships them with.
  builtin_services = {
    https       = "HTTPS"
    ssh         = "SSH"
    rdp         = "RDP"
    ftp         = "FTP"
    icmp_all    = "ICMP ALL"
    icmp_echo   = "ICMP Echo Request"
    smtp        = "SMTP"
    smtp_tls    = "SMTP_TLS"
    dns_tcp     = "DNS-TCP"
    dns_udp     = "DNS-UDP"
    ntp         = "NTP"
    dhcp_server = "DHCP-Server"
    ad          = "Microsoft Active Directory V1"
    syslog_tcp  = "Syslog (TCP)"
    syslog_udp  = "Syslog (UDP)"
    nfs         = "NFS (TCP)"
    iscsi       = "VMware-iSCSI-Server"
  }

  # Ports used by the design that have no built-in NSX service. TCP/5480 matches only the built-in
  # "HBR Server App" (vSphere Replication), which would mislabel the rules, so it stays custom.
  custom_services = {
    vami         = { description = "Appliance management (VAMI)", protocol = "TCP", ports = ["5480"] }
    k8s_api      = { description = "Kubernetes API", protocol = "TCP", ports = ["6443"] }
    syslog_tls   = { description = "Log management syslog over TLS", protocol = "TCP", ports = ["1514"] }
    log_api      = { description = "Log management ingestion API (TLS)", protocol = "TCP", ports = ["9543"] }
    salt         = { description = "VCF Management Services Salt", protocol = "TCP", ports = ["4505-4506"] }
    ops_networks = { description = "VCF Operations for Networks", protocol = "TCP", ports = ["1991"] }
    netflow      = { description = "VCF Operations for Networks flows", protocol = "UDP", ports = ["2055"] }
    messaging    = { description = "SSP / License Hub messaging", protocol = "TCP", ports = ["9092"] }
  }

  missing_builtin_services = [
    for name in values(local.builtin_services) : name
    if !contains(keys(data.nsxt_policy_services.all.items), name)
  ]
}

resource "nsxt_policy_service" "custom" {
  for_each = local.custom_services

  display_name = "${each.value.protocol}-${replace(join("_", each.value.ports), "-", "_")}"
  description  = each.value.description

  l4_port_set_entry {
    protocol          = each.value.protocol
    destination_ports = each.value.ports
  }
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
