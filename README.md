# terraform-nsxt-vcf-management-security

OpenTofu / Terraform module that deploys vDefend Distributed Firewall groups and policies protecting
the management components of a VMware Cloud Foundation (VCF) 9.1 fleet. It follows the
**VCF Management Domain Security** design blueprint
([Lateral Security with vDefend](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-blueprints-for/security-modernization/vdefend-lateral-security.html)),
including its group names, and extends it to multiple workload domains, shared NSX Managers, Avi
Load Balancer and Security Services Platform (SSP) placement.

Apply it with the provider pointed at the **management domain NSX Manager**, which enforces the
DFW for the VCF management components of every domain.

## Usage

```hcl
module "vcf_management_security" {
  source = "<registry or git source>"

  external_services = {
    bastion = ["192.0.2.10"]
    dns     = ["192.0.2.53"]
    ntp     = ["192.0.2.123"]
  }

  fleet_management = {
    vcf_operations_prefix             = "vcf-ops01"
    vcf_operations_cloud_proxy_prefix = "vcf-cp01"
    vcf_management_services_prefix    = "vcf-ms01-"
    vcf_automation_prefix             = "vcf-auto01-"
    vcf_automation_lb_ips             = ["198.51.100.20"]
    sddc_manager_name                 = "m01-sddc01"
    license_server_name               = "vcf-lic01"
    license_hub_name                  = "vcf-lhub01"
    ssp_installer_name                = "vcf-sspi01"
  }

  nsx_manager_clusters = {
    m01 = { vm_name_prefix = "m01-nsx01" }
    w01 = { vm_name_prefix = "w01-nsx01", avi = { controller_prefix = "w01-avi01" } }
  }

  management_domain = {
    name                = "m01"
    vcenter_name        = "m01-vc01"
    nsx_manager_cluster = "m01"
    hosts               = ["198.51.100.0/27"]
  }

  workload_domains = {
    w01 = { vcenter_name   = "w01-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.0/28"] }
    w02 = { vcenter_name   = "w02-vc01", nsx_manager_cluster = "w01", hosts = ["203.0.113.16/28"] }
  }
}
```

See [examples/basic](examples/basic) for a complete configuration with every option.

## Model

**Zones.** As in the design guide:
- a VCF Fleet zone (`VCF_FLEET`);
- a Fleet Management zone (`VCF_FM`);
- one zone per domain (`VCF01_M01`, `VCF01_W01`, …).

Each zone gets an Environment policy with an intra-zone *Jump to Application* rule, explicit
inter-zone allows and a logged lock-down rule.

**NSX Manager clusters** are declared once in `nsx_manager_clusters` and referenced by each domain's
`nsx_manager_cluster`.
- Several workload domains can share a cluster, and a workload domain can share the management
  domain's cluster.
- The cluster's groups are nested into every domain that uses it:
  - `<C>_NSX`;
  - `<C>_AVI` (one Avi controller cluster per NSX Manager, VCF-AVI-LB-REQD-CFG-03);
  - `<C>_SSP` (one SSP instance per NSX Manager, SSP-REQD-CFG-003).

**SSP** instances are always managed by the single SSP Installer in the management domain
(`VCF01_SSPI01`, part of `VCF_FM`). The SSP VMs run either in the management domain or in a workload
domain using the same NSX Manager (`ssp.domain`). Their node and Service IP Pool groups are nested
into that domain only.

**NSX Edge nodes** belong to an NSX Manager. Edges shared by every domain on an NSX Manager go on the
cluster (`nsx_manager_clusters[*].edges`, group `<C>_NSX_EDGE`, nested into each of those domains).
Edges dedicated to one domain go on that domain (`edges`, group `<D>_EDGE`).

**Avi Service Engines** run in workload domain clusters, so their networks are given per domain
(`avi_service_engines`).

**VCF 9.1 log management** runs on VCF Management Services. Log sources send to its integrated load
balancer VIPs, which NSX discovers on the Management Services node holding them, so `VCF01_MSVC`
(matched by VM name) covers log ingestion.

### Groups

| Group | Membership |
|---|---|
| `VCF_FLEET` | `VCF_FM` and every domain group |
| `VCF_FM` | The fleet management groups below |
| `VCF_OPS`, `VCF01_SDDC`, `VCF01_LIC`, `VCF01_LHUB`, `VCF01_SSPI01`, `VCF_OPS_NET` | VM tag `vcf_fm\|<component>`, applied by the module to the VM with that name (single-instance components) or the VMs with that prefix |
| `VCF01_OPS_CP`, `VCF01_OPS_NET_CN`, `VCF_A`, `VCF01_MSVC` | VM name starts with the prefix |
| `VCF_A_LB`, `VCF_A_EXT_LB` | VCF Automation native / external load balancer IPs |
| `VCF01_<D>` | IP groups tagged with scope `<d>`, plus `<D>_VC`, the cluster's `<C>_NSX` / `<C>_AVI`, and SSPs hosted in the domain |
| `<D>_VC` | VM name equals `vcenter_name` (survives reduced-downtime upgrades) |
| `<D>_HOSTS`, `<D>_EDGE`, `<D>_SUP`, `<D>_AVI_SE`, `<D>_STORAGE` | IP addresses; created only when given |
| `<C>_NSX`, `<C>_AVI`, `<C>_SSP` | VM name starts with the prefix |
| `<C>_SSP_SVC` | SSP Service IP Pool, tagged with the hosting domain |
| `<C>_NSX_EDGE` | Shared NSX Edge node IPs, tagged with every domain using the NSX Manager; created only when given |
| `BASTION`, `TOOLS`, `BACKUP_SVC`, `SMTP_SVC`, `SIEM_SVC`, `DNS_SVC`, `NTP_SVC`, `DHCP_SVC`, `AD_SVC`, `SYSLOG_SVC`, `LOG_ARCHIVE_SVC` | IP addresses; empty when not given |

`VCF01` comes from `vcf_instance_name`, `<D>` is the upper-cased domain key and `<C>` the upper-cased
cluster key.

### Policies

| Policy | Category | Applied to |
|---|---|---|
| VCF Fleet Environment | Environment (1) | `VCF_FLEET` |
| VCF Fleet Management Environment | Environment (2) | `VCF_FM` |
| VCF01 `<D>` Environment | Environment (3, then 4+ for workload domains) | `VCF01_<D>` |
| VCF Infrastructure Policy | Infrastructure | `VCF_FLEET` |
| VCF Automation Portal Access | Application | `VCF_A` |

Services use NSX built-ins wherever one exists. They are found with a single `nsxt_policy_services`
lookup, and planning fails with a list of names if a built-in is missing. Ports without a built-in
are created as custom services.

## Rollout

`lockdown_action` defaults to `ALLOW`: every lock-down rule logs instead of dropping, so a first
apply cannot cut off management traffic (MDS-REQD-CFG-035).
1. Review the logs for the labels `infra`, `vcf_fm`, `vcf01_<d>` and `vcf_a`.
2. Add any missing allow rules.
3. Set `lockdown_action = "DROP"`.

## Manual steps and caveats

- **DFW exclusion list** (MDS-REQD-CFG-018/019): remove the VCF management components from the
  `VCF-Created-Virtual-Machines` user excluded group. In 9.1.0 that group also has VM name criteria
  for VCF Management Services, Operations for Networks and Automation, which must be deleted. Keep
  the management NSX Managers (and workload domain NSX Managers shared with the management domain)
  in the DFW excluded group. This module does not manage the exclusion list.
- **Default rule:** the intra-zone *Jump to Application* rules end at the NSX default rule, which
  this module does not manage.
- **VM tags:** `nsxt_policy_vm_tags` replaces all NSX tags of the fleet management VMs it tags. The
  module fails if two fleet management names or prefixes match the same VM.
- **Upgrades:** the DNS and FQDN rules use Layer 7 context profiles, so in-place NSX upgrades through
  SDDC Manager are not supported while they are active (MDS-REQD-CFG-023).
- **Ports:** confirm the log management ports (syslog, TCP/1514, TCP/9543) and the depot FQDNs
  (`internet_fqdns`) against <https://ports.broadcom.com> for your release.

## Differences from the design guide

- Avi controller groups match by VM name instead of NSX tag (MDS-REQD-CFG-004), so that one Avi
  cluster can be nested into every domain sharing its NSX Manager.
- The Management Services rules also allow TCP/1514 (syslog over TLS).
- Mail uses the built-in `SMTP` and `SMTP_TLS` (TCP/587) services; NSX has no `SMTP_SSL` built-in.
- The Fleet policy adds a log management archive rule to `LOG_ARCHIVE_SVC` (NFS, HTTPS for S3).
- The Infrastructure syslog rule also allows `SIEM_SVC` and `VCF01_MSVC`. The guide's
  Infrastructure lock-down would otherwise drop syslog to VCF Management Services before the
  Environment rules allow it.
- MDS-REQD-CFG-028 doesn't spell out the Application policy for VCF Automation. Here it allows
  HTTPS to the native load balancer IPs and from external load balancers, and applies the
  lock-down action to direct HTTPS from outside `VCF_FLEET`.

## Testing

```sh
tofu init -backend=false
tofu test
```

The tests run offline against a mocked `nsxt` provider.

## Credits

The policy design follows Broadcom's VCF 9.1 design blueprints and started from the
[vmware-nsx/vcf-mgmt-wld-security](https://github.com/vmware-nsx/vcf-mgmt-wld-security) sample.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_nsxt"></a> [nsxt](#requirement\_nsxt) | >= 3.12.1, < 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_common"></a> [common](#module\_common) | ./modules/common | n/a |
| <a name="module_domain"></a> [domain](#module\_domain) | ./modules/domain | n/a |
| <a name="module_fleet_management"></a> [fleet\_management](#module\_fleet\_management) | ./modules/fleet-management | n/a |
| <a name="module_fleet_policies"></a> [fleet\_policies](#module\_fleet\_policies) | ./modules/fleet-policies | n/a |
| <a name="module_nsx_manager_cluster"></a> [nsx\_manager\_cluster](#module\_nsx\_manager\_cluster) | ./modules/nsx-manager-cluster | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_external_services"></a> [external\_services](#input\_external\_services) | IP addresses, ranges or CIDRs of the infrastructure and external services the VCF fleet uses.<br/>An empty list creates an empty group, so the rules for that service match nothing.<br/>`log_archive` holds the NFS or S3 targets that log management archives to. | <pre>object({<br/>    bastion     = optional(list(string), [])<br/>    tools       = optional(list(string), [])<br/>    backup      = optional(list(string), [])<br/>    smtp        = optional(list(string), [])<br/>    siem        = optional(list(string), [])<br/>    dns         = list(string)<br/>    ntp         = list(string)<br/>    dhcp        = optional(list(string), [])<br/>    ad          = optional(list(string), [])<br/>    syslog      = optional(list(string), [])<br/>    log_archive = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_fleet_management"></a> [fleet\_management](#input\_fleet\_management) | VCF fleet management components. `*_name` values are the VM names of single-instance components;<br/>`*_prefix` values are VM name prefixes of components that can have several VMs.<br/>`vcf_automation_lb_ips` are the VCF Automation native load balancer IPs. Leave<br/>`vcf_operations_networks` unset if VCF Operations for Networks is not deployed. | <pre>object({<br/>    vcf_operations_prefix             = string<br/>    vcf_operations_cloud_proxy_prefix = string<br/>    vcf_management_services_prefix    = string<br/>    vcf_automation_prefix             = string<br/>    vcf_automation_lb_ips             = list(string)<br/>    vcf_automation_external_lb_ips    = optional(list(string), [])<br/>    sddc_manager_name                 = string<br/>    license_server_name               = string<br/>    license_hub_name                  = string<br/>    ssp_installer_name                = string<br/>    vcf_operations_networks = optional(object({<br/>      platform_prefix  = string<br/>      collector_prefix = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_internet_fqdns"></a> [internet\_fqdns](#input\_internet\_fqdns) | Domain names the VCF fleet may reach over HTTPS for depot and upgrade downloads (MDS-REQD-CFG-030). The design guide lists specific hosts; see https://ports.broadcom.com for the current list. | `list(string)` | <pre>[<br/>  "*.broadcom.com",<br/>  "*.vmware.com",<br/>  "*.broadcom.net"<br/>]</pre> | no |
| <a name="input_lockdown_action"></a> [lockdown\_action](#input\_lockdown\_action) | Action of every lock-down rule. Start with ALLOW (logged) and switch to DROP once the lock-down logs show no legitimate traffic (MDS-REQD-CFG-035). | `string` | `"ALLOW"` | no |
| <a name="input_management_domain"></a> [management\_domain](#input\_management\_domain) | The management domain. `name` is its key (e.g. m01). `nsx_manager_cluster` is a key of<br/>`nsx_manager_clusters`. `edges` lists NSX Edge nodes dedicated to this domain (shared ones go on<br/>the NSX Manager cluster). `avi_service_engines` lists the Avi Service Engine management networks<br/>of SEs running in this domain. | <pre>object({<br/>    name                = string<br/>    vcenter_name        = string<br/>    nsx_manager_cluster = string<br/>    hosts               = list(string)<br/>    edges               = optional(list(string), [])<br/>    avi_service_engines = optional(list(string), [])<br/>    ip_storage          = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_nsx_manager_clusters"></a> [nsx\_manager\_clusters](#input\_nsx\_manager\_clusters) | NSX Manager clusters, including the management domain's, by key. Several domains can share one<br/>cluster. `edges` lists NSX Edge nodes shared by every domain using the cluster; edges dedicated to<br/>one domain go on that domain instead.<br/>`avi` is the Avi Load Balancer controller cluster onboarded to it (one per NSX Manager).<br/>`ssp` is the Security Services Platform instance onboarded to it; `ssp.domain` is the domain<br/>hosting the SSP VMs (default: the management domain), which must use this cluster or be the<br/>management domain. `ssp.service_pool` is the SSP Service IP Pool. | <pre>map(object({<br/>    vm_name_prefix = string<br/>    edges          = optional(list(string), [])<br/>    avi = optional(object({<br/>      controller_prefix = string<br/>    }))<br/>    ssp = optional(object({<br/>      node_prefix  = string<br/>      service_pool = list(string)<br/>      domain       = optional(string)<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_vcf_instance_name"></a> [vcf\_instance\_name](#input\_vcf\_instance\_name) | VCF instance name. Its upper-case form prefixes the instance-level group names (e.g. VCF01\_M01, VCF01\_SDDC). | `string` | `"vcf01"` | no |
| <a name="input_workload_domains"></a> [workload\_domains](#input\_workload\_domains) | Workload domains by key (e.g. w01). `nsx_manager_cluster` is a key of `nsx_manager_clusters`; it<br/>can be shared with other workload domains or the management domain. `supervisors` lists the<br/>vSphere Supervisor management networks. `edges` lists NSX Edge nodes dedicated to this domain<br/>(shared ones go on the NSX Manager cluster). `avi_service_engines` lists the Avi Service Engine<br/>management networks of SEs running in this domain. | <pre>map(object({<br/>    vcenter_name        = string<br/>    nsx_manager_cluster = string<br/>    hosts               = list(string)<br/>    edges               = optional(list(string), [])<br/>    supervisors         = optional(list(string), [])<br/>    avi_service_engines = optional(list(string), [])<br/>    ip_storage          = optional(list(string), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_domain_group_paths"></a> [domain\_group\_paths](#output\_domain\_group\_paths) | Policy paths of each domain's groups, with the groups statically included in its nested group. |
| <a name="output_external_group_paths"></a> [external\_group\_paths](#output\_external\_group\_paths) | Policy paths of the infrastructure and external service groups. |
| <a name="output_fleet_group_paths"></a> [fleet\_group\_paths](#output\_fleet\_group\_paths) | Policy paths of VCF\_FLEET and the fleet management groups. |
| <a name="output_nsx_manager_cluster_group_paths"></a> [nsx\_manager\_cluster\_group\_paths](#output\_nsx\_manager\_cluster\_group\_paths) | Policy paths of each NSX Manager cluster's groups. |
| <a name="output_policy_paths"></a> [policy\_paths](#output\_policy\_paths) | Policy paths of all security policies. |
<!-- END_TF_DOCS -->
