variable "nsx_manager" {
  type        = string
  description = "Management domain NSX Manager cluster VIP hostname or IP address."
}

variable "nsx_username" {
  type        = string
  description = "NSX Manager user with Enterprise Admin rights."
}

variable "nsx_password" {
  type        = string
  sensitive   = true
  description = "Password of nsx_username."
}

variable "nsx_allow_unverified_ssl" {
  type        = bool
  default     = false
  description = "Skip verification of the NSX Manager certificate."
}

variable "external_services" {
  type        = any
  description = "See the module's external_services input."
}

variable "fleet_management" {
  type        = any
  description = "See the module's fleet_management input."
}

variable "nsx_manager_clusters" {
  type        = any
  description = "See the module's nsx_manager_clusters input."
}

variable "management_domain" {
  type        = any
  description = "See the module's management_domain input."
}

variable "workload_domains" {
  type        = any
  default     = {}
  description = "See the module's workload_domains input."
}

variable "hpe_oneview_hsms" {
  type        = any
  default     = {}
  description = "See the module's hpe_oneview_hsms input."
}

variable "application_lockdown_action" {
  type        = string
  default     = "ALLOW"
  description = "See the module's application_lockdown_action input."
}

variable "lockdown_action" {
  type        = string
  default     = "ALLOW"
  description = "See the module's lockdown_action input."
}
