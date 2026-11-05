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

**Zones.** As in the guide's Segmentation Planning diagram and Environment policies:
- the **VCF Fleet Management Zone** (`VCF_FM`);
- the **Management domain Zone** (`VCF01_<MGMT>`);
- the **Workload Domain Zones** (`VCF01_W(...)`).

The VCF Fleet policy spans all of them through `VCF_FLEET`. Infrastructure and external services
(the diagram's InfraSvc and External zones) are IP groups.

A workload domain zone holds one workload domain, or the workload domains sharing an NSX Manager
cluster. The diagram shows both cases:
- a "Workload Domain #1/2 Zone" around two workload domains sharing an NSX Manager and Security
  Services Platform;
- a "Workload Domain #3 Zone" for a workload domain with its own NSX Manager.

The Environment policy footnote describes `VCF01_W(...)` as "all associated workload domains (WLD01,
shared WLD02/03, etc.)". A workload domain using the management domain's NSX Manager cluster joins
the Management domain Zone.

This also keeps a shared NSX Manager in a single zone policy. In several, the first policy's
lock-down would catch the other domains' traffic to it.

Each zone gets an Environment policy with:
- an intra-zone *Jump to Application* rule;
- explicit inter-zone allows;
- a logged lock-down rule.

A component shared by several domains (NSX Managers, Avi controllers) therefore sits in exactly one
zone policy.

**Application layer.** Traffic within a zone, and the explicit jumps, reach per-component
Application policies. Each policy ends with its own lock-down.
- Source: ported from the VCF 9.0 version of the design (SEC-MD-CFG-035..041) and its sample code.
  The 9.1 blueprint leaves this layer out.
- Coverage: transport nodes to NSX Manager, hosts to vCenter, Avi, SSP, VCF Operations and VCF
  Automation.
- Effect: the NSX default rule can later be tightened without cutting off management traffic.

**NSX Manager clusters** are declared once in `nsx_manager_clusters` and referenced by each domain's
`nsx_manager_cluster`. Several workload domains can share a cluster, and a workload domain can share
the management domain's.

Each cluster has:
- `<C>_NSX`;
- `<C>_AVI` (one Avi controller cluster per NSX Manager, VCF-AVI-LB-REQD-CFG-03);
- `<C>_SSP` (one SSP instance per NSX Manager, SSP-REQD-CFG-003).

NSX Edge nodes are given per domain (`<D>_EDGE`). Every domain's edge group is nested into its zone,
so an edge cluster shared by workload domains on one NSX Manager can be listed on any of them.

**SSP** instances are managed by the single SSP Installer (`VCF01_SSPI01`, part of `VCF_FM`) and
belong to their NSX Manager's zone. Their VMs run in one of two places:

| Where (`ssp.domain`) | Grouped by | DFW-protected |
|---|---|---|
| Management domain (default) | VM name, `ssp.node_prefix` | Yes, with its own Application policy |
| A workload domain using that NSX Manager | IP, `ssp.node_pool` (the Node IP Pool) | No: outside this NSX Manager's inventory |

**Avi Service Engines** and **Supervisors** run in workload domain clusters, so their networks are
given per domain (`avi_service_engines`, `supervisors`).

**VCF 9.1 log management** runs on VCF Management Services. Log sources send to its integrated load
balancer VIPs. NSX discovers each VIP on the Management Services node holding it, so `VCF01_MSVC`
(matched by VM name) covers log ingestion.

### Groups

| Group | Membership |
|---|---|
| `VCF_FLEET` | `VCF_FM`, the management domain zone and every workload domain zone |
| `VCF_FM` | The fleet management groups below |
| `VCF_OPS`, `VCF01_SDDC`, `VCF01_LIC`, `VCF01_LHUB`, `VCF01_SSPI01`, `VCF_OPS_NET` | VM tag `vcf_fm\|<component>`, applied by the module to the VM with that name (single-instance components) or the VMs with that prefix |
| `VCF01_OPS_CP`, `VCF01_OPS_NET_CN`, `VCF_A`, `VCF01_MSVC` | VM name starts with the prefix |
| `VCF_A_NLB`, `VCF_A_ELB` | VCF Automation native / external load balancer IPs |
| `VCF01_<ZONE>` | Management domain or workload domain zone: IP groups tagged with the NSX Manager cluster key, plus every member domain's `<D>_VC`, `<C>_NSX`, `<C>_AVI` and a name-based `<C>_SSP` |
| `<D>_VC` | VM name equals `vcenter_name` (survives reduced-downtime upgrades) |
| `<D>_HOSTS`, `<D>_EDGE`, `<D>_SUP`, `<D>_AVI_SE` | IP addresses, tagged with the zone; created only when given |
| `<C>_NSX`, `<C>_AVI` | VM name starts with the prefix |
| `<C>_SSP` | VM name starts with `node_prefix`, or IP group from `node_pool` |
| `<C>_SSP_SVC` | SSP Service IP Pool, tagged with the NSX Manager cluster key |
| `BASTION`, `TOOLS`, `BACKUP_SVC`, `SMTP_SVC`, `SIEM_SVC`, `DNS_SVC`, `NTP_SVC`, `DHCP_SVC`, `AD_SVC`, `SYSLOG_SVC`, `LOG_ARCHIVE_SVC` | IP addresses; empty when not given |

`VCF01` comes from `vcf_instance_name`. `<D>` is the upper-cased domain key. For zone and NSX
Manager cluster objects, `<C>` differs between ID and display name:
- **Group IDs** (`nsx_id`) use the upper-cased cluster key, which never changes.
- **Display names** use the domains using that NSX Manager, management domain first and then
  workload domains sorted, e.g. `VCF01_M01` or `VCF01_W01_W02`, as in
  the guide's "Workload Domain #1/2 Zone".

When a new workload domain starts sharing an NSX Manager, the zone and its groups and policies are
renamed in place. Nothing is replaced.

To stay within NSX's 255-character display-name limit:
- the label falls back to the cluster key when the domain list is longer than 128 characters;
- `nsx_manager_clusters[*].display_name` sets your own label (up to 64 characters);
- keys are limited to 64 characters and `vcf_instance_name` to 32.

### Policies

| Policy | Category | Applied to |
|---|---|---|
| VCF Fleet Policy | Environment (1) | `VCF_FLEET` |
| VCF Fleet Management Policy | Environment (2) | `VCF_FM` |
| VCF01 Management Domain Policy | Environment (3) | the management domain zone |
| VCF01 Workload Domain `<ZONE>` Policy | Environment (4+) | each workload domain zone |
| VCF Infrastructure Policy | Infrastructure | `VCF_FLEET` |
| VCF Operations Policy | Application | `VCF_OPS`, `VCF01_OPS_CP`, `VCF01_SDDC` |
| VCF Operations for Networks Policy | Application (if deployed) | `VCF_OPS_NET`, `VCF01_OPS_NET_CN` |
| VCF Automation Policy | Application | `VCF_A` |
| Management Domain / Workload Domain `<D>` vCenter Policy | Application (per domain) | `<D>_VC` |
| Workload Domain `<ZONE>` NSX Manager Policy | Application (not for the management domain's NSX Manager, which stays DFW-excluded) | `<C>_NSX` |
| Management Domain / Workload Domain `<ZONE>` Avi Load Balancer Policy | Application (if Avi) | `<C>_AVI` |
| Management Domain / Workload Domain `<ZONE>` SSP Policy | Application (SSP in the management domain) | `<C>_SSP` |

Policy names follow the guide: the 9.1 Environment policies, and the 9.0 Application policies.
Lockdown rules are named "`<policy>` Lockdown".

Services use NSX built-ins wherever one exists. They are found with a single `nsxt_policy_services`
lookup, and planning fails with a list of names if a built-in is missing. Ports without a built-in
are created as custom services.

## Rollout

Both lock-down variables default to `ALLOW`: every lock-down rule logs instead of dropping, so a
first apply cannot cut off management traffic (MDS-REQD-CFG-035, SEC-MD-CFG-041).
1. Apply with both at `ALLOW`.
2. Review the Environment and Infrastructure lock-down logs: labels `infra`, `vcf_fm` and
   `vcf01_<c>`.
3. Set `lockdown_action = "DROP"`.
4. Review the Application lock-down logs: labels `app_ops`, `app_ops_net`, `app_vcf_a`,
   `app_<d>_vc`, `app_<c>_nsx`, `app_<c>_avi` and `app_<c>_ssp`.
5. Set `application_lockdown_action = "DROP"`.
6. Only then consider tightening the NSX default rule.

## Manual steps and caveats

- **DFW exclusion list** (MDS-REQD-CFG-018/019):
  - Remove the VCF management components from the `VCF-Created-Virtual-Machines` user excluded
    group. In 9.1.0 that group also has VM name criteria for VCF Management Services, Operations
    for Networks and Automation, which must be deleted.
  - Keep the management NSX Managers (and workload domain NSX Managers shared with the management
    domain) in the DFW excluded group.
  - This module does not manage the exclusion list.
- **Default rule:** traffic no Application policy matches ends at the NSX default rule, which this
  module does not manage.
- **VM tags:** `nsxt_policy_vm_tags` replaces all NSX tags of the fleet management VMs it tags. The
  module fails if two fleet management names or prefixes match the same VM.
- **Upgrades:** the DNS and FQDN rules use Layer 7 context profiles, so in-place NSX upgrades through
  SDDC Manager are not supported while they are active (MDS-REQD-CFG-023).
- **Ports:** confirm the log management ports (syslog, TCP/1514, TCP/9543) and the depot FQDNs
  (`internet_fqdns`) against <https://ports.broadcom.com> for your release.
- **Check before `application_lockdown_action = "DROP"`:** flows the 9.0 policies don't cover and
  that may show up in the logs:
  - vCenter reduced downtime upgrades: the temporary vCenter VM has a different name;
  - vCenter ↔ vCenter within a zone;
  - NSX Manager ↔ Avi endpoint registration;
  - fleet management components ↔ License Server or License Hub.

## Differences from the design guide

- **IP-based storage:** groups for IP storage such as NFS (MDS-REQD-CFG-007, "if exists") are not
  created yet.
- **Application layer from VCF 9.0, adapted to 9.1:**
  - VCF Operations for Logs and the fleet management appliance are replaced by VCF Management
    Services.
  - VCF Operations fleet management → VCF Automation (SSH, HTTPS, TCP/6443, TCP/30000-30005) comes
    from `VCF01_MSVC`, since 9.1 runs fleet management on VCF Management Services. The 9.0 design used
    the fleet management appliance (`VCF_OPS_FM`). Watch the `app_vcf_a` lockdown logs to see which
    Management Services addresses actually connect.
  - Additions:
    - fleet components → `VCF01_MSVC`;
    - NSX Manager → SSP Service IP Pool (HTTPS, TCP/9092);
    - SSP → NSX in the NSX Manager policy;
    - a Fleet rule that jumps SSP threat-feed traffic to its Application policy.
- **Avi:** controller groups match by VM name instead of NSX tag (MDS-REQD-CFG-004), so that one Avi
  cluster serves every domain sharing its NSX Manager.
- **Management Services rules:** they also allow TCP/1514 (syslog over TLS).
- **Mail:** it uses the built-in `SMTP` and `SMTP_TLS` (TCP/587) services; NSX has no `SMTP_SSL`
  built-in.
- **Log archive:** the Fleet policy adds a log management archive rule to `LOG_ARCHIVE_SVC` (NFS,
  HTTPS for S3).
- **Infrastructure syslog:** the rule also allows `SIEM_SVC` and `VCF01_MSVC`. The guide's
  Infrastructure lock-down would otherwise drop syslog to VCF Management Services before the
  Environment rules allow it.

## Testing

```sh
tofu init -backend=false
tofu test
```

The tests run offline against a mocked `nsxt` provider.

## Credits

The policy design follows Broadcom's VCF 9.1 design blueprints, with the Application layer from the
VCF 9.0 Lateral Security validated solution. It started from the
[vmware-nsx/vcf-mgmt-wld-security](https://github.com/vmware-nsx/vcf-mgmt-wld-security) sample
(including its `vcf-9.0` branch).

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
| <a name="module_zone"></a> [zone](#module\_zone) | ./modules/zone | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application_lockdown_action"></a> [application\_lockdown\_action](#input\_application\_lockdown\_action) | Action of the Application-category lock-down rules (VCF 9.0 SEC-MD-CFG-041). Move to DROP after lockdown\_action, once the Application lock-down logs show no legitimate traffic. | `string` | `"ALLOW"` | no |
| <a name="input_external_services"></a> [external\_services](#input\_external\_services) | IP addresses, ranges or CIDRs of the infrastructure and external services the VCF fleet uses.<br/>An empty list creates an empty group, so the rules for that service match nothing.<br/>`log_archive` holds the NFS or S3 targets that log management archives to. | <pre>object({<br/>    bastion     = optional(list(string), [])<br/>    tools       = optional(list(string), [])<br/>    backup      = optional(list(string), [])<br/>    smtp        = optional(list(string), [])<br/>    siem        = optional(list(string), [])<br/>    dns         = list(string)<br/>    ntp         = list(string)<br/>    dhcp        = optional(list(string), [])<br/>    ad          = optional(list(string), [])<br/>    syslog      = optional(list(string), [])<br/>    log_archive = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_fleet_management"></a> [fleet\_management](#input\_fleet\_management) | VCF fleet management components. `*_name` values are the VM names of single-instance components;<br/>`*_prefix` values are VM name prefixes of components that can have several VMs.<br/>`vcf_automation_lb_ips` are the VCF Automation native load balancer IPs. Leave `vcf_operations_networks` unset if VCF<br/>Operations for Networks is not deployed. | <pre>object({<br/>    vcf_operations_prefix               = string<br/>    vcf_operations_cloud_proxy_prefix   = string<br/>    vcf_management_services_prefix      = string<br/>    vcf_automation_prefix               = string<br/>    vcf_automation_lb_ips               = list(string)<br/>    vcf_automation_external_lb_ips      = optional(list(string), [])<br/>    sddc_manager_name                   = string<br/>    license_server_name                 = string<br/>    license_hub_name                    = string<br/>    ssp_installer_name                  = string<br/>    vcf_operations_networks = optional(object({<br/>      platform_prefix  = string<br/>      collector_prefix = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_internet_fqdns"></a> [internet\_fqdns](#input\_internet\_fqdns) | Domain names the VCF fleet may reach over HTTPS for depot and upgrade downloads (MDS-REQD-CFG-030). The design guide lists specific hosts; see https://ports.broadcom.com for the current list. | `list(string)` | <pre>[<br/>  "*.broadcom.com",<br/>  "*.vmware.com",<br/>  "*.broadcom.net"<br/>]</pre> | no |
| <a name="input_lockdown_action"></a> [lockdown\_action](#input\_lockdown\_action) | Action of the Environment and Infrastructure lock-down rules. Start with ALLOW (logged) and switch to DROP once the lock-down logs show no legitimate traffic (MDS-REQD-CFG-035). | `string` | `"ALLOW"` | no |
| <a name="input_management_domain"></a> [management\_domain](#input\_management\_domain) | The management domain. `name` is its key (e.g. m01). `nsx_manager_cluster` is a key of<br/>`nsx_manager_clusters`. `edges` lists NSX Edge nodes in this domain; an edge cluster shared by<br/>workload domains on one NSX Manager can be listed on any of them. `avi_service_engines` lists the Avi Service Engine management networks<br/>of SEs running in this domain. | <pre>object({<br/>    name                = string<br/>    vcenter_name        = string<br/>    nsx_manager_cluster = string<br/>    hosts               = list(string)<br/>    edges               = optional(list(string), [])<br/>    avi_service_engines = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_nsx_manager_clusters"></a> [nsx\_manager\_clusters](#input\_nsx\_manager\_clusters) | NSX Manager clusters, including the management domain's, by key. Several domains can share one<br/>cluster.<br/>`avi` is the Avi Load Balancer controller cluster onboarded to it (one per NSX Manager).<br/>`ssp` is the Security Services Platform instance onboarded to it; `ssp.domain` is the domain<br/>hosting the SSP VMs (default: the management domain), which must use this cluster or be the<br/>management domain. SSP VMs in the management domain are matched by `ssp.node_prefix`; SSP VMs in a<br/>workload domain are outside this NSX Manager's inventory and are matched by `ssp.node_pool` (the<br/>SSP Node IP Pool). `ssp.service_pool` is the SSP Service IP Pool.<br/>The domains using a cluster form one zone: the management domain zone, or a workload domain zone<br/>(like the guide's "Workload Domain #1/2 Zone" for workload domains sharing an NSX Manager). The<br/>zone's group IDs use the key. Its display names use the domains in it (management domain first,<br/>then workload domains sorted), or `display_name` if set, or the key if the domain list is longer<br/>than 128 characters. | <pre>map(object({<br/>    vm_name_prefix = string<br/>    display_name   = optional(string)<br/>    avi = optional(object({<br/>      controller_prefix = string<br/>    }))<br/>    ssp = optional(object({<br/>      node_prefix  = optional(string)<br/>      node_pool    = optional(list(string), [])<br/>      service_pool = list(string)<br/>      domain       = optional(string)<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_vcf_instance_name"></a> [vcf\_instance\_name](#input\_vcf\_instance\_name) | VCF instance name. Its upper-case form prefixes the instance-level group names (e.g. VCF01\_M01, VCF01\_SDDC). | `string` | `"vcf01"` | no |
| <a name="input_workload_domains"></a> [workload\_domains](#input\_workload\_domains) | Workload domains by key (e.g. w01). `nsx_manager_cluster` is a key of `nsx_manager_clusters`; it<br/>can be shared with other workload domains or the management domain. `supervisors` lists the<br/>vSphere Supervisor management networks. `edges` lists NSX Edge nodes in this domain; an<br/>edge cluster shared by workload domains on one NSX Manager can be listed on any of them.<br/>`avi_service_engines` lists the Avi Service Engine<br/>management networks of SEs running in this domain. | <pre>map(object({<br/>    vcenter_name        = string<br/>    nsx_manager_cluster = string<br/>    hosts               = list(string)<br/>    edges               = optional(list(string), [])<br/>    supervisors         = optional(list(string), [])<br/>    avi_service_engines = optional(list(string), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_domain_group_paths"></a> [domain\_group\_paths](#output\_domain\_group\_paths) | Policy paths of each domain's groups. |
| <a name="output_external_group_paths"></a> [external\_group\_paths](#output\_external\_group\_paths) | Policy paths of the infrastructure and external service groups. |
| <a name="output_fleet_group_paths"></a> [fleet\_group\_paths](#output\_fleet\_group\_paths) | Policy paths of VCF\_FLEET and the fleet management groups. |
| <a name="output_nsx_manager_cluster_group_paths"></a> [nsx\_manager\_cluster\_group\_paths](#output\_nsx\_manager\_cluster\_group\_paths) | Policy paths of each NSX Manager cluster's groups. |
| <a name="output_policy_paths"></a> [policy\_paths](#output\_policy\_paths) | Policy paths of all security policies. |
| <a name="output_zone_group_paths"></a> [zone\_group\_paths](#output\_zone\_group\_paths) | The management domain zone and each workload domain zone (keyed by NSX Manager cluster): the zone group's path and display name, and the groups statically included in it. |
<!-- END_TF_DOCS -->
