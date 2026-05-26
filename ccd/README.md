# Infosys CCD Infrastructure - Terraform Deployment

This Terraform project deploys the CCD (Corp Tenant) infrastructure on Azure with Power Platform VNet integration support.

---

## Architecture Overview

The deployment creates a hub-style network architecture in a primary Azure region with a secondary VNet in a paired region for Power Platform failover. All resources are deployed into a single resource group.

```
Primary VNet (centralindia)              Secondary VNet (southindia)
┌─────────────────────────────┐          ┌──────────────────────────────┐
│ AzureFirewallSubnet         │          │ snet-pp-agent-southindia     │
│ snet-apim (APIM + NSG)     │◄────────►│ (PP delegation)              │
│ snet-pe (Private Endpoints) │ Peering  └──────────────────────────────┘
│ snet-pp-agent (PP delegation│
└─────────────────────────────┘
         │
    Azure Firewall ──► Route Table (0.0.0.0/0 → FW Private IP)
         │
    Firewall Policy + Rules
```

---

## Why Two VNets?

Power Platform VNet integration requires **subnet delegation** to `Microsoft.PowerPlatform/enterprisePolicies` in **both Azure regions** of your Power Platform region pair.

The **Enterprise Policy** (deployed via ARM template in this code) registers both VNets with Power Platform for failover support. The ARM template parameter `vNetTwoResourceId` and `vNetTwoSubnetName` **require** the secondary VNet to be present.

**Example**: If your Power Platform environment is in **India**, you need:
- **Primary VNet** in `centralindia` — contains firewall, APIM, private endpoints, and a PP-delegated subnet
- **Secondary VNet** in `southindia` — contains only one PP-delegated subnet

> **Single VNet option**: If you only need a single VNet (without the Enterprise Policy), comment out these resources in `main.tf`:
> 1. `module "pp_secondary_vnet"` — The secondary VNet
> 2. `azurerm_private_dns_zone_virtual_network_link.*_secondary` — All secondary DNS links (keyvault_secondary, apim_secondary, blob_secondary, file_secondary)
> 3. `module "vnet_peering_primary_to_secondary"` — VNet peering
> 4. `azurerm_resource_group_template_deployment "pp_enterprise_policy"` — The Enterprise Policy ARM deployment
>
> You will then need to create the Enterprise Policy separately through the Azure portal or PowerShell, referencing only the primary VNet.

---

## Resource Inventory

### 1. Resource Group

| Resource | Name | Location |
|----------|------|----------|
| Azure Resource Group | `rg-infosys-ccd-prod-001` | `centralindia` |

### 2. Networking

#### Primary Virtual Network

| Resource | Name | Configuration |
|----------|------|---------------|
| Virtual Network | `vnet-infosys-ccd-prod-001` | Address space: `10.30.0.0/24`, Region: `centralindia` |

**Subnets:**

| Subnet | Name | Address Prefix | Delegation | NSG |
|--------|------|----------------|------------|-----|
| AzureFirewallSubnet | `AzureFirewallSubnet` | `10.30.0.0/26` | None | None |
| APIM Subnet | `snet-apim` | `10.30.0.64/27` | `Microsoft.Web/serverFarms` | `nsg-apim-infosys-prod-001` |
| Power Platform Subnet | `snet-pp-agent` | `10.30.0.96/27` | `Microsoft.PowerPlatform/enterprisePolicies` | None |
| Private Endpoint Subnet | `snet-pe` | `10.30.0.128/27` | None | None |

#### Secondary Virtual Network (Power Platform Paired Region)

| Resource | Name | Configuration |
|----------|------|---------------|
| Virtual Network | `vnet-pp-infosys-prod-southindia` | Address space: `10.31.0.0/24`, Region: `southindia` |

**Subnets:**

| Subnet | Name | Address Prefix | Delegation |
|--------|------|----------------|------------|
| Power Platform Subnet | `snet-pp-agent-southindia` | `10.31.0.0/26` | `Microsoft.PowerPlatform/enterprisePolicies` |

> This secondary VNet is **required** for the Enterprise Policy deployment. The Enterprise Policy ARM template needs both VNets to register the PP environment for failover.

#### Network Security Group

| Resource | Name | Associated Subnet |
|----------|------|-------------------|
| NSG | `nsg-apim-infosys-prod-001` | `snet-apim` |

#### VNet Peering (Optional)

| Resource | Name | Direction |
|----------|------|-----------|
| VNet Peering | `peer-primary-to-southindia` | Primary → Secondary |
| VNet Peering | `peer-southindia-to-primary` | Secondary → Primary |

Controlled by `enable_vnet_peering` variable. When disabled, a warning output is generated reminding you to ensure connectivity via another mechanism (e.g., Azure Firewall, ExpressRoute, VPN Gateway).

#### Route Table

| Resource | Name | Associated Subnet |
|----------|------|-------------------|
| Route Table | `rt-infosys-ccd-prod-001` | `snet-apim` |

**Routes:**

| Route | Address Prefix | Next Hop Type | Next Hop |
|-------|----------------|---------------|----------|
| `default-to-firewall` | `0.0.0.0/0` | VirtualAppliance | Azure Firewall private IP |

### 3. Azure Firewall

| Resource | Name | Configuration |
|----------|------|---------------|
| Public IP | `pip-afw-infosys-ccd-prod-001` | Static, Standard SKU, Zone-redundant (1,2,3) |
| Firewall Policy | `afwp-infosys-ccd-prod-001` | Standard tier |
| Azure Firewall | `afw-infosys-ccd-prod-001` | SKU: `AZFW_VNet`, Tier: Standard, Zones: 1,2,3 |

#### Firewall Rules

**Network Rule Collection** (`network-rules`, Priority: 200, Action: Allow):

| Rule | Source | Destination | Protocols | Ports |
|------|--------|-------------|-----------|-------|
| `apim-to-pp-subnet` | APIM subnet (`10.30.0.64/27`) | PP subnet (`10.30.0.96/27`) | Any | `*` |
| `pp-subnet-to-pe-subnet` | PP subnet (`10.30.0.96/27`) | PE subnet (`10.30.0.128/27`) | Any | `*` |
| `apim-to-pe-subnet` | APIM subnet (`10.30.0.64/27`) | PE subnet (`10.30.0.128/27`) | Any | `*` |

**Application Rule Collection** (`application-rules`, Priority: 300, Action: Allow):

| Rule | Source | Protocols | Destination FQDNs |
|------|--------|-----------|-------------------|
| `allow-http-https` | `*` | HTTP:80, HTTPS:443 | `*` |

### 4. Azure Key Vault

| Resource | Name | Configuration |
|----------|------|---------------|
| Key Vault | `kv-infosys-ccd-prod-001` | Public access: Disabled, Private endpoint on `snet-pe` |

### 5. API Management

| Resource | Name | Configuration |
|----------|------|---------------|
| API Management | `apim-infosys-ccd-prod-001` | SKU: `StandardV2_1`, VNet: External on `snet-apim`, System-assigned managed identity, Publisher: Contoso |

**Post-deployment configuration (via AzAPI):**

- Public network access disabled (runs once via `azapi_update_resource` with `lifecycle { ignore_changes }`)

**Private Endpoint:**

| Endpoint | Subnet | DNS Zone |
|----------|--------|----------|
| `pe-apim-infosys-ccd-prod-001` | `snet-pe` | `privatelink.azure-api.net` |

### 6. Private DNS Zones

| DNS Zone | Purpose |
|----------|---------|
| `privatelink.vaultcore.azure.net` | Key Vault |
| `privatelink.azure-api.net` | API Management |
| `privatelink.blob.core.windows.net` | Blob Storage |
| `privatelink.file.core.windows.net` | File Storage |

#### Virtual Network Links

Each DNS zone is linked to **both** VNets (primary in `centralindia` and secondary in `southindia`):

| DNS Zone | Primary VNet Link | Secondary VNet Link |
|----------|-------------------|---------------------|
| Key Vault | `link-keyvault-primary` | `link-keyvault-secondary` |
| APIM | `link-apim-primary` | `link-apim-secondary` |
| Blob | `link-blob-primary` | `link-blob-secondary` |
| File | `link-file-primary` | `link-file-secondary` |

### 7. Power Platform Enterprise Policy

| Resource | Name | Configuration |
|----------|------|---------------|
| Enterprise Policy (ARM) | `ep-infosys-ccd-prod-001` | Kind: `NetworkInjection`, Region: `centralindia` |

Deployed via ARM template. Links **both** the primary VNet (`vnet-infosys-ccd-prod-001` in `centralindia`) and secondary VNet (`vnet-pp-infosys-prod-southindia` in `southindia`) with their respective Power Platform delegated subnets for failover support.

---

## Power Platform Region Mapping

The deployment automatically determines the paired Azure regions based on the `power_platform_region` input. The `resource_group_location` must be one of the Azure regions in the pair.

**Example**: `power_platform_region = "India"` → primary VNet in `centralindia`, secondary VNet in `southindia`.

| Power Platform Region | Azure Region 1 | Azure Region 2 |
|-----------------------|-----------------|-----------------|
| United States | eastus | westus |
| South Africa | southafricanorth | southafricawest |
| UK | uksouth | ukwest |
| Japan | japaneast | japanwest |
| **India** | **centralindia** | **southindia** |
| France | francecentral | francesouth |
| Europe | westeurope | northeurope |
| Germany | germanynorth | germanywestcentral |
| Switzerland | switzerlandnorth | switzerlandwest |
| Canada | canadacentral | canadaeast |
| Brazil | brazilsouth | (single region) |
| Australia | australiasoutheast | australiaeast |
| Asia | eastasia | southeastasia |
| UAE | uaenorth | (single region) |
| Korea | koreasouth | koreacentral |
| Norway | norwaywest | norwayeast |
| Singapore | southeastasia | (single region) |
| Sweden | swedencentral | (single region) |
| Italy | italynorth | (single region) |
| US Government | usgovtexas | usgovvirginia |

> **Note**: Regions marked `(single region)` have only one Azure region. For these, the secondary VNet, DNS links, peering, and second VNet reference in the Enterprise Policy are automatically skipped.

---

## Prerequisites

### Azure Prerequisites

1. **Terraform** >= 1.5.0
2. **Azure CLI** installed and authenticated (`az login`)
3. **Providers**: `azurerm ~> 4.0`, `azapi ~> 2.0`
4. **Azure permissions**:
   - **Contributor** role on the target subscription
   - **Storage Blob Data Contributor** on the backend storage account (for Azure AD–based state access)
5. **Backend storage account** must exist with container `tfstate` in resource group `rg-infosys-dev-01`
6. **Azure subscription** must be linked to your Power Platform tenant

### Power Platform Prerequisites

1. **Power Platform environment** must be created and available in one of the [supported regions](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview#supported-regions)
2. **Identify your PP environment region** — Run `Get-EnvironmentRegion` from the [subnet diagnostics PowerShell module](https://learn.microsoft.com/en-us/troubleshoot/power-platform/administration/virtual-network#use-the-diagnostics-powershell-module) to confirm the exact Azure region your environment uses
3. **`resource_group_location`** must be set to one of the Azure regions in your PP region's pair (e.g., if PP region is `"India"`, set `resource_group_location = "centralindia"`)
4. **Power Platform admin access** — Required to link the Enterprise Policy to the PP environment post-deployment
5. **Environment type** — Must be Production, Default, Sandbox, or Developer (Trial and Dataverse for Teams are **not supported**)
6. **Review plug-ins and connectors** — Before enabling VNet support, verify all Dataverse plug-ins and connectors can work with private connectivity. Public endpoints will be blocked by network policies after enablement

### Supported Power Platform Environment Types

| Type | VNet Support |
|------|-------------|
| Production | Yes |
| Default | Yes |
| Sandbox | Yes |
| Developer | Yes |
| Trial | No |
| Dataverse for Teams | No |

---

## File Structure

```
├── backend.tf                              # Remote state configuration (Azure Storage, Azure AD auth)
├── provider.tf                             # Provider versions (azurerm, azapi)
├── variables.tf                            # Input variable declarations with validations
├── terraform.tfvars                        # Variable values for the environment
├── main.tf                                 # All resource definitions
├── output.tf                               # Output values
├── generate_report.py                      # Script to generate Excel resource inventory
├── Infosys_CCD_Resource_Inventory.xlsx     # Generated Excel report
└── README.md                               # This file
```

---

## Input Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `resource_group_name` | string | Resource group name | `""` |
| `resource_group_location` | string | Primary Azure region (must match a PP region pair) | `""` |
| `nsg_apim_name` | string | APIM NSG name | — |
| `virtual_network_name` | string | Primary VNet name | — |
| `vnet_address_space` | string | Primary VNet CIDR | — |
| `firewall_subnet_address_prefix` | string | Firewall subnet CIDR | — |
| `apim_subnet_name` | string | APIM subnet name | — |
| `apim_subnet_address_prefix` | string | APIM subnet CIDR | — |
| `private_endpoint_subnet_name` | string | Private endpoint subnet name | — |
| `private_endpoint_subnet_address_prefix` | string | Private endpoint subnet CIDR | — |
| `power_platform_region` | string | Power Platform region (e.g., `"India"`) | — |
| `pp_subnet_name` | string | PP subnet name in primary VNet | — |
| `pp_subnet_address_prefix` | string | PP subnet CIDR in primary VNet | — |
| `pp_secondary_vnet_name` | string | Secondary VNet name prefix | — |
| `pp_secondary_vnet_address_space` | string | Secondary VNet CIDR | — |
| `pp_secondary_subnet_address_prefix` | string | PP subnet CIDR in secondary VNet | — |
| `enable_vnet_peering` | bool | Enable VNet peering between primary and secondary | `false` |
| `key_vault_name` | string | Key Vault name | — |
| `firewall_policy_name` | string | Firewall Policy name | — |
| `firewall_name` | string | Azure Firewall name | — |
| `firewall_public_ip_name` | string | Firewall Public IP name | — |
| `apim_name` | string | API Management name | — |
| `apim_sku_name` | string | APIM SKU (e.g., `StandardV2_1`) | — |
| `pp_enterprise_policy_name` | string | PP Enterprise Policy name | — |
| `route_table_name` | string | Route table name | — |

---

## Deployment Guide

### Step 1: Authenticate to Azure

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

### Step 2: Verify Backend Storage Access

Ensure your identity has **Storage Blob Data Contributor** role on the backend storage account:

```powershell
az role assignment create `
  --role "Storage Blob Data Contributor" `
  --assignee "<YOUR_OBJECT_ID>" `
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-infosys-dev-01/providers/Microsoft.Storage/storageAccounts/rginfosysdev0183f4"
```

### Step 3: Review and Customize Variables

Edit `terraform.tfvars` to match your environment. Example for **India** region:

```hcl
resource_group_name     = "rg-infosys-ccd-prod-001"
resource_group_location = "centralindia"          # Must be one of the PP region pair

power_platform_region = "India"                   # Maps to centralindia + southindia

pp_subnet_name           = "snet-pp-agent"
pp_subnet_address_prefix = "10.30.0.96/27"

pp_secondary_vnet_name             = "vnet-pp-infosys-prod"    # Will become vnet-pp-infosys-prod-southindia
pp_secondary_vnet_address_space    = "10.31.0.0/24"
pp_secondary_subnet_address_prefix = "10.31.0.0/26"

enable_vnet_peering = true                        # Recommended for connectivity between VNets
```

Key points:
- `resource_group_location` must be one of the regions in the `power_platform_region` pair
- `power_platform_region` determines which paired Azure regions are used
- Address spaces for primary and secondary VNets must **not overlap**
- Set `enable_vnet_peering = true` for automatic VNet peering (recommended)

### Step 4: Initialize Terraform

```powershell
terraform init
```

This downloads all required AVM modules and configures the remote backend.

### Step 5: Review the Plan

```powershell
terraform plan -out=tfplan
```

Review the output to confirm the resources to be created. Expected resource count varies based on `enable_vnet_peering` setting and whether the PP region has a paired region.

### Step 6: Apply

```powershell
terraform apply tfplan
```

**Deployment order** (handled automatically by dependency graph):

1. Resource Group (`rg-infosys-ccd-prod-001` in `centralindia`)
2. Route Table, NSG, Public IP
3. Primary VNet with 4 subnets (`centralindia`), Secondary VNet with 1 subnet (`southindia`)
4. Private DNS Zones (Key Vault, APIM, Blob, File)
5. DNS Zone Virtual Network Links (8 links: 4 zones × 2 VNets)
6. Key Vault + Private Endpoint
7. Firewall Policy → Azure Firewall → Firewall Rules
8. API Management (External VNet integration on `snet-apim`) + Private Endpoint
9. VNet Peering (if enabled)
10. Enterprise Policy (ARM template — registers both VNets with Power Platform)
11. APIM public access disabled (AzAPI, runs once)

### Step 7: Verify Outputs

```powershell
terraform output
```

Key outputs include VNet IDs, subnet IDs, firewall private IP, Key Vault ID, APIM ID, secondary region, and the VNet peering warning message.

### Step 8: Re-run Validation

```powershell
terraform plan
```

On subsequent runs, `terraform plan` should show **0 to add, 0 to destroy**. The only expected change is a cosmetic ARM template type casing update (`"String"` → `"string"`) which is a harmless Azure provider behavior.

---

## Post-Deployment Steps

### 1. Link Enterprise Policy to Power Platform Environment

After Terraform completes, the Enterprise Policy exists in Azure but is **not yet linked** to your Power Platform environment. Follow these steps:

1. Install the Power Platform admin PowerShell module:
   ```powershell
   Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
   ```

2. Connect to your tenant:
   ```powershell
   Add-PowerAppsAccount
   ```

3. Link the enterprise policy to your environment:
   ```powershell
   New-PowerAppEnvironmentSubnet -EnvironmentName "<PP_ENVIRONMENT_ID>" -EnterprisePolicyArmId "/subscriptions/<SUB_ID>/resourceGroups/rg-infosys-ccd-prod-001/providers/Microsoft.PowerPlatform/enterprisePolicies/ep-infosys-ccd-prod-001"
   ```

For detailed instructions see: [Set up Virtual Network support](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure)

### 2. Verify Subnet Delegation

Confirm both subnets show `Microsoft.PowerPlatform/enterprisePolicies` delegation in the Azure portal:
- `snet-pp-agent` in primary VNet (`centralindia`)
- `snet-pp-agent-southindia` in secondary VNet (`southindia`)

### 3. Validate DNS Resolution

From a resource inside the VNet, verify private DNS resolution for:
- `*.vaultcore.azure.net`
- `*.azure-api.net`
- `*.blob.core.windows.net`
- `*.file.core.windows.net`

### 4. Test Connectivity

- Verify that Dataverse plug-ins can reach private endpoints through the delegated subnets
- Validate firewall rules allow expected traffic flows (APIM ↔ PP subnet ↔ PE subnet)
- Confirm APIM is accessible only through the private endpoint (public access should be disabled)

---

## Single VNet Deployment (Without Enterprise Policy)

If you only need the primary VNet without the Enterprise Policy and secondary VNet, comment out the following resources in `main.tf`:

```hcl
# 1. Comment out the secondary VNet module
# module "pp_secondary_vnet" { ... }

# 2. Comment out all secondary DNS VNet links
# resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_secondary" { ... }
# resource "azurerm_private_dns_zone_virtual_network_link" "apim_secondary" { ... }
# resource "azurerm_private_dns_zone_virtual_network_link" "blob_secondary" { ... }
# resource "azurerm_private_dns_zone_virtual_network_link" "file_secondary" { ... }

# 3. Comment out VNet peering
# module "vnet_peering_primary_to_secondary" { ... }

# 4. Comment out the Enterprise Policy ARM deployment
# resource "azurerm_resource_group_template_deployment" "pp_enterprise_policy" { ... }
```

You will then need to create and link the Enterprise Policy manually through the Azure portal or PowerShell, referencing only the primary VNet's PP subnet.

---

## Destroying the Infrastructure

```powershell
terraform destroy
```

> **Important**: Before destroying, you **must** unlink the Enterprise Policy from the Power Platform environment first:
> 1. Run `Remove-PowerAppEnvironmentSubnet` to disconnect the PP environment
> 2. Wait for the operation to complete
> 3. Then run `terraform destroy`
>
> See: [Remove subnet injection](https://github.com/microsoft/PowerPlatform-EnterprisePolicies/blob/main/README.md#9-remove-subnet-injection-from-an-environment)

---

## Important Notes

- **APIM Public Access**: `StandardV2` SKU does not allow `publicNetworkAccess = Disabled` at creation time. The code creates APIM with public access enabled, then disables it via AzAPI with `lifecycle { ignore_changes }` to prevent re-enabling on subsequent runs.
- **APIM VNet Integration**: `External` VNet integration is configured directly in the APIM module to ensure idempotency.
- **Secondary VNet is Required for Enterprise Policy**: The ARM template deploys a `Microsoft.PowerPlatform/enterprisePolicies` resource that requires both VNets for PP regions with two Azure regions. If you only want one VNet, see the [Single VNet Deployment](#single-vnet-deployment-without-enterprise-policy) section.
- **VNet Peering**: If disabled, ensure both VNets can communicate through another mechanism (Azure Firewall, ExpressRoute, VPN Gateway) for Power Platform VNet integration to function.
- **Subnet Sizing**: Plan your PP subnet size based on [Microsoft's guidance](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview#estimating-subnet-size-for-power-platform-environments) — 25–30 IPs per production environment, 6–10 per non-production.
- **Backend Auth**: The state backend uses Azure AD authentication (`use_azuread_auth = true`) since key-based access is disabled on the storage account.
- **Single-Region PP Regions**: Brazil, UAE, Singapore, Sweden, and Italy only have one Azure region. The secondary VNet, DNS links, and peering are automatically skipped for these regions.
