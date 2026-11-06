# AGENTS.md

Guidance for coding agents and contributors working on this module.

## What this is

An OpenTofu / Terraform module (`vmware/nsxt` provider) that deploys vDefend DFW groups and policies
for the management components of a VMware Cloud Foundation 9.1 fleet. It follows Broadcom's design
guidance:

- **VCF 9.1 Management Domain Security blueprint:** segmentation (zones), grouping, Infrastructure
  and Environment policies.
  <https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-blueprints-for/security-modernization/vdefend-lateral-security.html>
- **VCF 9.0 Lateral Security validated solution:** the Application-category policies, which the
  9.1 blueprint leaves out.
- **VCF 9.1 design library:** Avi Load Balancer, SSP and log management details.
- **Ports:** <https://ports.broadcom.com>.

The README's "Differences from the design guide" section lists every intentional deviation. Keep it
current.

## Commands

```sh
tofu init -backend=false     # also after adding or renaming test run blocks that use module {}
tofu fmt -recursive
tofu validate
tofu test                    # offline; the nsxt provider is mocked
terraform-docs markdown table --output-file README.md --output-mode inject .
```

- Every change must pass `tofu fmt -check -recursive`, `tofu validate` and `tofu test`.
- Regenerate the README inputs/outputs block with terraform-docs after changing variables or
  outputs. Don't edit that block by hand.
- The pre-commit hooks (`.pre-commit-config.yaml`) run fmt, docs and validate with `tofu`.

## Layout and data flow

```
common               custom services + one services lookup, context profiles, external/infra IP groups
fleet-management     fleet component VM tags and groups, VCF_FM
nsx-manager-cluster  per NSX Manager cluster: <C>_NSX, <C>_AVI, <C>_SSP, <C>_SSP_SVC
domain               per domain: <D>_VC, <D>_HOSTS, <D>_EDGE, <D>_SUP, <D>_AVI_SE
zone                 per NSX Manager cluster: zone group, Environment policy, vCenter/NSX/Avi/SSP
                     Application policies
hsm-hpe-oneview      per HPE OneView HSM: HSM_<KEY>, HSM_<KEY>_OV, HSM_<KEY>_ILO; its Fleet rules
fleet-policies       VCF_FLEET; Fleet, Fleet Management, Infrastructure and fleet Application policies
```

The root `main.tf` wires them in that order. Modules exchange typed objects, and there are no cycles
between module calls. Keep it that way: an instance of a module call cannot depend on another
instance of the same call.

## Design rules

- **Use the guide's terminology and names**, for groups, policies, zones ("Management domain
  Zone", "Workload Domain Zone") and requirement IDs (MDS-REQD-CFG-xxx, SEC-MD-CFG-xxx). When
  something isn't from the guide, say so in a comment and in the README's differences section.
  Don't present an interpretation as the guide's statement.
- **Zones:** one zone per NSX Manager cluster. Workload domains sharing an NSX Manager form one
  workload domain zone (the guide's "Workload Domain #1/2 Zone"), so a shared NSX Manager or Avi
  controller is in exactly one zone policy.
- **Stable IDs, readable names:** `nsx_id` comes from keys that never change (the NSX Manager
  cluster key, the domain key). Display names may follow domain names and change in place. Keep
  every display name within 255 characters (there is a test) and log labels within 32.
- **Never create an empty match-all:**
  - an empty prefix must not match every VM;
  - an empty group list in a rule means "any", so rules whose peer list can be empty are `dynamic`
    and skipped;
  - empty IP lists give empty groups.
- **Services:** use NSX built-in services wherever one matches the protocol and port exactly. Create
  custom services only for ports with no built-in, each covering one port or one contiguous range
  (e.g. TCP/4505-4506). Custom services live in `modules/common`, keyed by their display name, with
  `create_before_destroy` (so a removed service is deleted after the rules stop using it). The single
  `nsxt_policy_services` lookup there `depends_on` them, so its map holds built-ins and custom services
  alike; rules index it by NSX display name (`var.service_paths["HTTPS"]`). Don't add another layer of
  logical names, and don't give a custom service a display name another NSX service already uses.
  Don't combine unrelated ports such as 22 and 443 into one custom service without explicit
  confirmation; built-ins may cover several. Check direction and protocol against
  ports.broadcom.com: a built-in describes the server side.
- **Hardware Support Managers:** one root input and one module per vendor (`hpe_oneview_hsms`,
  `modules/hsm-hpe-oneview`). A vendor module creates its groups and returns its appliance groups
  (which join `VCF_FLEET`) and a vendor-neutral rule list that fleet-policies places in the VCF
  Fleet Policy. Ports come from the vendor's documentation, cited in the module. Keep `HSM_<KEY>`
  unique across vendor inputs.
- **VM tags:** `nsxt_policy_vm_tags` owns a VM's entire tag set. Only fleet management components
  are tagged, and no VM may be matched by two lookups. Group shared components by VM name and
  nest them; don't tag them.
- **Lockdowns:** `lockdown_action` and `application_lockdown_action` default to `ALLOW` (logged)
  for the staged rollout. Never change those defaults to `DROP`.
- **Validation:** cross-variable checks must stay acyclic: `nsx_manager_clusters` ←
  `management_domain` ← `workload_domains`. A validation must reference its own variable.

## Public repository rule

This repository is public and must stay generic:

- no organization- or environment-specific hostnames, VM names, IP addresses or platform/CI
  references;
- examples and tests use RFC 5737 documentation ranges (`192.0.2.0/24`, `198.51.100.0/24`,
  `203.0.113.0/24`) and generic names (`m01-vc01`, `w01-nsx01`, …).

Before committing, check that no other IPv4 addresses appear:

```sh
git ls-files -co --exclude-standard | xargs grep -n -o -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | grep -v -E '192\.0\.2\.|198\.51\.100\.|203\.0\.113\.'
```

## Tests

- `tests/root.tftest.hcl` checks wiring through root outputs. Assertions can't reach resources
  inside child modules.
- One test file per submodule (`run { module { source = "./modules/<name>" } }`) checks resource
  attributes directly.
- Mocks:
  - `mock_data "nsxt_policy_services"` must list every built-in and custom display name the rules use;
  - group paths must be valid policy paths;
  - `override_resource` / `override_data` give specific instances distinct values.
- Runs that expect a validation or precondition failure use `command = plan` and `expect_failures`.
