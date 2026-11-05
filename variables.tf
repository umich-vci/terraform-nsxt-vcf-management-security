variable "vcf_instance_name" {
  type        = string
  default     = "vcf01"
  description = "VCF instance name. Its upper-case form prefixes the instance-level group names (e.g. VCF01_M01, VCF01_SDDC)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{0,31}$", var.vcf_instance_name))
    error_message = "vcf_instance_name must be at most 32 lower-case letters, digits, '-' or '_'."
  }
}

variable "external_services" {
  type = object({
    bastion     = optional(list(string), [])
    tools       = optional(list(string), [])
    backup      = optional(list(string), [])
    smtp        = optional(list(string), [])
    siem        = optional(list(string), [])
    dns         = list(string)
    ntp         = list(string)
    dhcp        = optional(list(string), [])
    ad          = optional(list(string), [])
    syslog      = optional(list(string), [])
    log_archive = optional(list(string), [])
  })
  description = <<-EOT
    IP addresses, ranges or CIDRs of the infrastructure and external services the VCF fleet uses.
    An empty list creates an empty group, so the rules for that service match nothing.
    `log_archive` holds the NFS or S3 targets that log management archives to.
  EOT
}

variable "fleet_management" {
  type = object({
    vcf_operations_prefix             = string
    vcf_operations_cloud_proxy_prefix = string
    vcf_management_services_prefix    = string
    vcf_automation_prefix             = string
    vcf_automation_lb_ips             = list(string)
    vcf_automation_external_lb_ips    = optional(list(string), [])
    sddc_manager_name                 = string
    license_server_name               = string
    license_hub_name                  = string
    ssp_installer_name                = string
    vcf_operations_networks = optional(object({
      platform_prefix  = string
      collector_prefix = string
    }))
  })
  description = <<-EOT
    VCF fleet management components. `*_name` values are the VM names of single-instance components;
    `*_prefix` values are VM name prefixes of components that can have several VMs.
    `vcf_automation_lb_ips` are the VCF Automation native load balancer IPs. Leave `vcf_operations_networks` unset if VCF
    Operations for Networks is not deployed.
  EOT

  validation {
    condition = alltrue([
      for k, v in var.fleet_management : length(v) > 0 if endswith(k, "_prefix") || endswith(k, "_name")
    ]) && try(length(var.fleet_management.vcf_operations_networks.platform_prefix) > 0 && length(var.fleet_management.vcf_operations_networks.collector_prefix) > 0, true)
    error_message = "VM names and prefixes must not be empty."
  }
}

variable "nsx_manager_clusters" {
  type = map(object({
    vm_name_prefix = string
    display_name   = optional(string)
    avi = optional(object({
      controller_prefix = string
    }))
    ssp = optional(object({
      node_prefix  = optional(string)
      node_pool    = optional(list(string), [])
      service_pool = list(string)
      domain       = optional(string)
    }))
  }))
  description = <<-EOT
    NSX Manager clusters, including the management domain's, by key. Several domains can share one
    cluster.
    `avi` is the Avi Load Balancer controller cluster onboarded to it (one per NSX Manager).
    `ssp` is the Security Services Platform instance onboarded to it; `ssp.domain` is the domain
    hosting the SSP VMs (default: the management domain), which must use this cluster or be the
    management domain. SSP VMs in the management domain are matched by `ssp.node_prefix`; SSP VMs in a
    workload domain are outside this NSX Manager's inventory and are matched by `ssp.node_pool` (the
    SSP Node IP Pool). `ssp.service_pool` is the SSP Service IP Pool.
    The domains using a cluster form one zone: the management domain zone, or a workload domain zone
    (like the guide's "Workload Domain #1/2 Zone" for workload domains sharing an NSX Manager). The
    zone's group IDs use the key. Its display names use the domains in it (management domain first,
    then workload domains sorted), or `display_name` if set, or the key if the domain list is longer
    than 128 characters.
  EOT

  validation {
    condition = alltrue([
      for k, c in var.nsx_manager_clusters :
      can(regex("^[a-z0-9][a-z0-9_-]{0,63}$", k)) && (c.display_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", c.display_name)))
    ])
    error_message = "NSX Manager cluster keys must be at most 64 lower-case letters, digits, '-' or '_'; display_name at most 64 letters, digits, '-' or '_'."
  }

  validation {
    condition = alltrue([
      for c in var.nsx_manager_clusters :
      length(c.vm_name_prefix) > 0 && try(length(c.avi.controller_prefix) > 0, true) && try(length(c.ssp.node_prefix) > 0, true)
    ])
    error_message = "VM name prefixes must not be empty."
  }
}

variable "management_domain" {
  type = object({
    name                = string
    vcenter_name        = string
    nsx_manager_cluster = string
    hosts               = list(string)
    edges               = optional(list(string), [])
    avi_service_engines = optional(list(string), [])
  })
  description = <<-EOT
    The management domain. `name` is its key (e.g. m01). `nsx_manager_cluster` is a key of
    `nsx_manager_clusters`. `edges` lists NSX Edge nodes in this domain; an edge cluster shared by
    workload domains on one NSX Manager can be listed on any of them. `avi_service_engines` lists the Avi Service Engine management networks
    of SEs running in this domain.
  EOT

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{0,63}$", var.management_domain.name)) && length(var.management_domain.vcenter_name) > 0
    error_message = "management_domain.name must be at most 64 lower-case letters, digits, '-' or '_', and vcenter_name must not be empty."
  }

  validation {
    condition     = contains(keys(var.nsx_manager_clusters), var.management_domain.nsx_manager_cluster)
    error_message = "management_domain.nsx_manager_cluster must be a key of nsx_manager_clusters."
  }

  validation {
    condition     = length(var.management_domain.avi_service_engines) == 0 || try(var.nsx_manager_clusters[var.management_domain.nsx_manager_cluster].avi != null, false)
    error_message = "management_domain.avi_service_engines requires Avi on its NSX Manager cluster."
  }

  validation {
    condition = alltrue([
      for k, c in var.nsx_manager_clusters : c.ssp == null || try(
        coalesce(c.ssp.domain, var.management_domain.name) == var.management_domain.name
        ? length(c.ssp.node_prefix) > 0
        : length(c.ssp.node_pool) > 0,
      false)
    ])
    error_message = "An SSP in the management domain needs ssp.node_prefix; an SSP in a workload domain needs ssp.node_pool."
  }
}

variable "workload_domains" {
  type = map(object({
    vcenter_name        = string
    nsx_manager_cluster = string
    hosts               = list(string)
    edges               = optional(list(string), [])
    supervisors         = optional(list(string), [])
    avi_service_engines = optional(list(string), [])
  }))
  default     = {}
  description = <<-EOT
    Workload domains by key (e.g. w01). `nsx_manager_cluster` is a key of `nsx_manager_clusters`; it
    can be shared with other workload domains or the management domain. `supervisors` lists the
    vSphere Supervisor management networks. `edges` lists NSX Edge nodes in this domain; an
    edge cluster shared by workload domains on one NSX Manager can be listed on any of them.
    `avi_service_engines` lists the Avi Service Engine
    management networks of SEs running in this domain.
  EOT

  validation {
    condition = alltrue([
      for k, w in var.workload_domains : can(regex("^[a-z0-9][a-z0-9_-]{0,63}$", k)) && k != var.management_domain.name && length(w.vcenter_name) > 0
    ])
    error_message = "Workload domain keys must be at most 64 lower-case letters, digits, '-' or '_' and differ from the management domain name; vcenter_name must not be empty."
  }

  validation {
    condition     = alltrue([for w in var.workload_domains : contains(keys(var.nsx_manager_clusters), w.nsx_manager_cluster)])
    error_message = "Each workload domain's nsx_manager_cluster must be a key of nsx_manager_clusters."
  }

  validation {
    condition = alltrue([
      for w in var.workload_domains : length(w.avi_service_engines) == 0 || try(var.nsx_manager_clusters[w.nsx_manager_cluster].avi != null, false)
    ])
    error_message = "avi_service_engines requires Avi on the workload domain's NSX Manager cluster."
  }

  # Validated here rather than on nsx_manager_clusters so the cross-variable references stay acyclic.
  validation {
    condition = alltrue([
      for k, c in var.nsx_manager_clusters : try(c.ssp.domain, null) == null || try(
        c.ssp.domain == var.management_domain.name || var.workload_domains[c.ssp.domain].nsx_manager_cluster == k,
      false)
    ])
    error_message = "nsx_manager_clusters[*].ssp.domain must be the management domain or a workload domain that uses the same NSX Manager cluster."
  }


  validation {
    condition = alltrue([
      for k in keys(var.nsx_manager_clusters) :
      k == var.management_domain.nsx_manager_cluster || anytrue([for w in var.workload_domains : w.nsx_manager_cluster == k])
    ])
    error_message = "Every NSX Manager cluster must be used by at least one domain."
  }
}

variable "internet_fqdns" {
  type        = list(string)
  default     = ["*.broadcom.com", "*.vmware.com", "*.broadcom.net"]
  description = "Domain names the VCF fleet may reach over HTTPS for depot and upgrade downloads (MDS-REQD-CFG-030). The design guide lists specific hosts; see https://ports.broadcom.com for the current list."
}

variable "lockdown_action" {
  type        = string
  default     = "ALLOW"
  description = "Action of the Environment and Infrastructure lock-down rules. Start with ALLOW (logged) and switch to DROP once the lock-down logs show no legitimate traffic (MDS-REQD-CFG-035)."

  validation {
    condition     = contains(["ALLOW", "DROP"], var.lockdown_action)
    error_message = "lockdown_action must be ALLOW or DROP."
  }
}

variable "application_lockdown_action" {
  type        = string
  default     = "ALLOW"
  description = "Action of the Application-category lock-down rules (VCF 9.0 SEC-MD-CFG-041). Move to DROP after lockdown_action, once the Application lock-down logs show no legitimate traffic."

  validation {
    condition     = contains(["ALLOW", "DROP"], var.application_lockdown_action)
    error_message = "application_lockdown_action must be ALLOW or DROP."
  }
}
