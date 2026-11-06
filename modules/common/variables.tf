variable "external_services" {
  type = object({
    bastion     = optional(list(string), [])
    tools       = optional(list(string), [])
    backup      = optional(list(string), [])
    smtp        = optional(list(string), [])
    siem        = optional(list(string), [])
    dns         = optional(list(string), [])
    ntp         = optional(list(string), [])
    dhcp        = optional(list(string), [])
    ad          = optional(list(string), [])
    syslog      = optional(list(string), [])
    log_archive = optional(list(string), [])
  })
  description = "IP addresses, ranges or CIDRs of the infrastructure and external services. An empty list creates an empty group, so rules that reference it match nothing."
}

variable "internet_fqdns" {
  type        = list(string)
  description = "Domain names the VCF fleet may reach over HTTPS for depot and upgrade traffic (MDS-REQD-CFG-030)."
}

variable "hardware_support_managers" {
  type = map(object({
    vm_name = optional(string)
    ips     = optional(list(string), [])
  }))
  default     = {}
  description = "Hardware Support Managers by key: their exact VM name and/or IP addresses."
}
