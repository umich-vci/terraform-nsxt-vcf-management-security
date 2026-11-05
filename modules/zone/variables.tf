variable "name" {
  type        = string
  description = "Key of the NSX Manager cluster whose domains form this zone. Its upper-case form is the zone group ID (e.g. w01 gives VCF01_W01)."
}

variable "display_name" {
  type        = string
  default     = null
  description = "Upper-case label used in the zone's group and policy display names (e.g. the domains in the zone). Defaults to the upper-case key. The group ID always uses the key, so the label can change in place."
}

variable "management_domain" {
  type        = string
  description = "Key of the management domain. A zone containing it is the management domain zone; the others are workload domain zones."
}

variable "instance" {
  type        = string
  description = "Upper-case VCF instance name used as the group name prefix (e.g. VCF01)."
}

variable "domains" {
  type = map(object({
    vc     = string
    hosts  = optional(string)
    edge   = optional(string)
    sup    = optional(string)
    avi_se = optional(string)
  }))
  description = "Group paths of the domains using this NSX Manager cluster, from the domain module."
}

variable "cluster_group_paths" {
  type = object({
    nsx     = string
    avi     = optional(string)
    ssp     = optional(string)
    ssp_svc = optional(string)
  })
  description = "Group paths of the NSX Manager cluster, from the nsx-manager-cluster module."
}

variable "nsx_dfw" {
  type        = bool
  description = "Whether the NSX Managers are protected by the DFW. False for the NSX Manager used by the management domain, which stays in the DFW exclusion list (MDS-REQD-CFG-019)."
}

variable "ssp_dfw" {
  type        = bool
  default     = false
  description = "Whether the SSP VMs run in the management domain and are protected by the DFW."
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
  description = "Policy paths of the fleet management groups referenced by the zone policy."
}

variable "service_paths" {
  type        = map(string)
  description = "Policy paths of services, by logical name, from the common module."
}

variable "sequence_number" {
  type        = number
  description = "Sequence number of the zone's Environment policy."
}

variable "application_sequence_number" {
  type        = number
  description = "First sequence number of the zone's Application policies."
}

variable "lockdown_action" {
  type        = string
  description = "Action of the Environment lock-down rule: ALLOW or DROP. Both log."
}

variable "application_lockdown_action" {
  type        = string
  description = "Action of the Application lock-down rules: ALLOW or DROP. Both log."
}
