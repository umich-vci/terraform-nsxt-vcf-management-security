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
