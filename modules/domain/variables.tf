variable "name" {
  type        = string
  description = "Domain key (e.g. m01, w01). Its upper-case form names the groups, and it is the tag scope of the domain's IP groups."
}

variable "instance" {
  type        = string
  description = "Upper-case VCF instance name used as the group name prefix (e.g. VCF01)."
}

variable "vcenter_name" {
  type        = string
  description = "VM name of the domain's vCenter Server."
}

variable "hosts" {
  type        = list(string)
  description = "ESX host management IP addresses, ranges or CIDRs."
}

variable "edges" {
  type        = list(string)
  default     = []
  description = "Management IP addresses, ranges or CIDRs of NSX Edge nodes dedicated to this domain."
}

variable "supervisors" {
  type        = list(string)
  default     = []
  description = "vSphere Supervisor management IP addresses, ranges or CIDRs."
}

variable "avi_service_engines" {
  type        = list(string)
  default     = []
  description = "Avi Service Engine management IP addresses, ranges or CIDRs for SEs running in this domain."
}

variable "ip_storage" {
  type        = list(string)
  default     = []
  description = "IP-based storage (e.g. NFS) IP addresses, ranges or CIDRs."
}

variable "cluster_group_paths" {
  type = object({
    nsx = string
    avi = optional(string)
  })
  description = "Policy paths of the NSX Manager and Avi controller groups of the NSX Manager cluster this domain uses."
}

variable "hosted_ssp_paths" {
  type        = list(string)
  default     = []
  description = "Policy paths of the SSP node groups of SSP instances deployed in this domain."
}

variable "fleet_group_paths" {
  type = object({
    vcf_fm         = string
    sddc           = string
    ops_cp         = string
    msvc           = string
    ops_net_cn     = string
    license_server = string
    license_hub    = string
    ssp_installer  = string
  })
  description = "Policy paths of the fleet management groups referenced by the domain policy."
}

variable "service_paths" {
  type        = map(string)
  description = "Policy paths of services, by logical name, from the common module."
}

variable "sequence_number" {
  type        = number
  description = "Sequence number of the domain's Environment policy."
}

variable "lockdown_action" {
  type        = string
  description = "Action of the lock-down rule: ALLOW or DROP. Both log."
}
