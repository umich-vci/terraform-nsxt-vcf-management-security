terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.12.1, < 4.0.0"
    }
  }
}

# The management domain NSX Manager, which protects the VCF management components.
provider "nsxt" {
  host                  = var.nsx_manager
  username              = var.nsx_username
  password              = var.nsx_password
  allow_unverified_ssl  = var.nsx_allow_unverified_ssl
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

module "vcf_management_security" {
  source = "../.."

  external_services    = var.external_services
  fleet_management     = var.fleet_management
  nsx_manager_clusters = var.nsx_manager_clusters
  management_domain    = var.management_domain
  workload_domains     = var.workload_domains
  lockdown_action      = var.lockdown_action

  hpe_oneview_hsms = var.hpe_oneview_hsms

  application_lockdown_action = var.application_lockdown_action
}
