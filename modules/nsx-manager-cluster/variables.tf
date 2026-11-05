variable "name" {
  type        = string
  description = "NSX Manager cluster key. Its upper-case form prefixes the group IDs (e.g. m01 gives M01_NSX), and it is the tag scope that places IP groups in the zone of the domains using it."
}

variable "display_name" {
  type        = string
  default     = null
  description = "Upper-case label used in group display names (e.g. the domains using this NSX Manager). Defaults to the upper-case key. Group IDs always use the key, so the label can change in place."
}

variable "vm_name_prefix" {
  type        = string
  description = "VM name prefix shared by the NSX Manager appliances of this cluster."
}

variable "avi" {
  type = object({
    controller_prefix = string
  })
  default     = null
  description = "Avi Load Balancer controller cluster onboarded to this NSX Manager (1:1, VCF-AVI-LB-REQD-CFG-03). Null if Avi is not deployed."
}

variable "ssp" {
  type = object({
    node_prefix  = optional(string)
    node_pool    = optional(list(string), [])
    service_pool = list(string)
  })
  default     = null
  description = "Security Services Platform instance onboarded to this NSX Manager. Null if SSP is not deployed."
}

variable "ssp_in_management_domain" {
  type        = bool
  default     = true
  description = "Whether the SSP VMs run in the management domain, where they are grouped by name and protected by the DFW. Otherwise they are grouped by their Node IP Pool."
}
