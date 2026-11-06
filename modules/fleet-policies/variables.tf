variable "zones" {
  type = map(object({
    zone        = string
    vcs         = list(string)
    nsx_and_avi = list(string)
    sups        = list(string)
  }))
  description = "Group paths of the management domain zone and every workload domain zone, from the zone module."
}

variable "dfw_ssp_paths" {
  type        = list(string)
  default     = []
  description = "SSP node groups of SSP instances running in the management domain (DFW-protected)."
}

variable "ops_networks_enabled" {
  type        = bool
  default     = false
  description = "Whether VCF Operations for Networks is deployed."
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
    vcf_a_nlb      = string
    vcf_a_elb      = string
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

variable "hsm_group_paths" {
  type        = list(string)
  default     = []
  description = "Policy paths of the Hardware Support Manager appliance groups, which join VCF_FLEET."
}

variable "hsm_rules" {
  type = list(object({
    display_name       = string
    source_groups      = list(string)
    destination_groups = list(string)
    services           = list(string)
    direction          = string
  }))
  default     = []
  description = "Hardware Support Manager rules for the VCF Fleet Policy, from the HSM vendor modules."
}

variable "application_lockdown_action" {
  type        = string
  description = "Action of the Application lock-down rules: ALLOW or DROP. Both log."
}

variable "lockdown_action" {
  type        = string
  description = "Action of the lock-down rules: ALLOW or DROP. Both log."
}
