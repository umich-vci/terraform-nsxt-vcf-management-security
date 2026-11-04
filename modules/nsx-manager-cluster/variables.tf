variable "name" {
  type        = string
  description = "NSX Manager cluster key; its upper-case form prefixes the group names (e.g. m01 gives M01_NSX)."
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
    node_prefix  = string
    service_pool = list(string)
  })
  default     = null
  description = "Security Services Platform instance onboarded to this NSX Manager. Null if SSP is not deployed."
}

variable "ssp_domain" {
  type        = string
  default     = null
  description = "Domain whose nested group the SSP instance belongs to (the domain hosting the SSP VMs)."
}
