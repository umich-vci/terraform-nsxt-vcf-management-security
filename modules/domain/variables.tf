variable "name" {
  type        = string
  description = "Domain key (e.g. m01, w01). Its upper-case form names the domain's groups."
}

variable "zone" {
  type        = string
  description = "Key of the NSX Manager cluster the domain uses. As tag scope it places the domain's IP groups in the zone of the domains using that NSX Manager."
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
  description = "Management IP addresses, ranges or CIDRs of NSX Edge nodes in this domain."
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
