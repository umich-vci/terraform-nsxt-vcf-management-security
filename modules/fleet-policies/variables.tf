variable "domains" {
  type = map(object({
    domain = string
    vc     = string
    nsx    = string
    avi    = optional(string)
    sup    = optional(string)
  }))
  description = "Group paths of every domain (management and workload), from the domain module."
}

variable "fleet_group_paths" {
  type = object({
    vcf_fm         = string
    ops            = string
    ops_networks   = string
    sddc           = string
    license_server = string
    license_hub    = string
    ssp_installer  = string
    ops_cp         = string
    ops_net_cn     = string
    vcf_a          = string
    msvc           = string
    vcf_a_lb       = string
    vcf_a_ext_lb   = string
  })
  description = "Policy paths of the fleet management groups, from the fleet-management module."
}

variable "external_group_paths" {
  type = object({
    bastion     = string
    tools       = string
    backup      = string
    smtp        = string
    siem        = string
    dns         = string
    ntp         = string
    dhcp        = string
    ad          = string
    syslog      = string
    log_archive = string
  })
  description = "Policy paths of the infrastructure and external service groups, from the common module."
}

variable "service_paths" {
  type        = map(string)
  description = "Policy paths of services, by logical name, from the common module."
}

variable "context_profile_paths" {
  type = object({
    dns            = string
    internet_fqdns = string
  })
  description = "Policy paths of the context profiles, from the common module."
}

variable "lockdown_action" {
  type        = string
  description = "Action of the lock-down rules: ALLOW or DROP. Both log."
}
