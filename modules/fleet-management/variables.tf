variable "instance" {
  type        = string
  description = "Upper-case VCF instance name used as the group name prefix (e.g. VCF01)."
}

variable "fleet_management" {
  type = object({
    vcf_operations_prefix             = string
    vcf_operations_cloud_proxy_prefix = string
    vcf_management_services_prefix    = string
    vcf_automation_prefix             = string
    vcf_automation_lb_ips             = list(string)
    vcf_automation_external_lb_ips    = optional(list(string), [])
    sddc_manager_name                 = string
    license_server_name               = string
    license_hub_name                  = string
    ssp_installer_name                = string
    vcf_operations_networks = optional(object({
      platform_prefix  = string
      collector_prefix = string
    }))
  })
  description = "VM names (single-instance components), VM name prefixes and IP addresses of the VCF fleet management components."
}
