variable "hsms" {
  type = map(object({
    vm_name = optional(string)
    ips     = optional(list(string), [])
    oneview = optional(list(string), [])
    ilo     = optional(list(string), [])
    vcs     = list(string)
    hosts   = optional(list(string), [])
  }))
  default     = {}
  description = "HPE OneView for VMware vCenter appliances by key: the appliance VM name and/or IPs, the OneView appliances (or Synergy Composers) and iLOs it manages, and the vCenter and ESX host groups of the domains that use it."
}

variable "service_paths" {
  type        = map(string)
  description = "Policy paths of NSX services, built-in and custom, by display name, from the common module."
}

variable "bastion" {
  type        = string
  description = "Policy path of the BASTION group, from the common module."
}
