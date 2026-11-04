terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.12.1, < 4.0.0"
    }
  }
}
