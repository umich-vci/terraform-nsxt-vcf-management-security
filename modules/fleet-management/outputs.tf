output "group_paths" {
  description = "Policy paths of the fleet management groups."
  value = {
    vcf_fm         = nsxt_policy_group.vcf_fm.path
    ops            = nsxt_policy_group.tagged["ops"].path
    ops_networks   = nsxt_policy_group.tagged["ops_networks"].path
    sddc           = nsxt_policy_group.tagged["sddc"].path
    license_server = nsxt_policy_group.tagged["license_server"].path
    license_hub    = nsxt_policy_group.tagged["license_hub"].path
    ssp_installer  = nsxt_policy_group.tagged["ssp_installer"].path
    ops_cp         = nsxt_policy_group.named["ops_cp"].path
    ops_net_cn     = nsxt_policy_group.named["ops_net_cn"].path
    vcf_a          = nsxt_policy_group.named["vcf_a"].path
    msvc           = nsxt_policy_group.named["msvc"].path
    vcf_a_lb       = nsxt_policy_group.vcf_a_lb["vcf_a_lb"].path
    vcf_a_ext_lb   = nsxt_policy_group.vcf_a_lb["vcf_a_ext_lb"].path
  }
}
