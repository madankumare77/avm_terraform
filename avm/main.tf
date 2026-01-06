

data "azurerm_resource_group" "rg" {
  name = "madan-test"
}

module "avm_res_network_virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.16.0"
  for_each = { for k, v in local.vnets_to_create : k => v if var.enable_virtual_networks }
  #for_each = local.vnets_to_create

  name     = each.value.name
  location = each.value.location
  parent_id = data.azurerm_resource_group.rg.id

  address_space = each.value.address_space

  enable_telemetry        = false
  dns_servers = (try(each.value.dns_servers, null) == null ? null: { dns_servers = each.value.dns_servers })

  tags                    = try(each.value.tags, {})

  # --- Transform your subnet_configs -> module.subnets expected shape ---
  subnets = {
    for sk, s in each.value.subnet_configs : sk => {
      name             = s.name
      address_prefixes = s.address_prefix

      # Convert ["Microsoft.KeyVault","Microsoft.Web"] -> [{service="Microsoft.KeyVault"}, {service="Microsoft.Web"}]
      service_endpoints_with_location = [
        for svc in try(s.service_endpoints, []) : {
          service = svc
          # locations = [each.value.location] # use only if you want location restriction
        }
      ]

      network_security_group = try((try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] }), null)

      # If delegation exists, create list; else empty
      delegations = try([
        {
          name = s.delegation.name
          service_delegation = {
            name    = s.delegation.service_delegation.name
            actions = s.delegation.service_delegation.actions
          }
        }
      ], [])
    }
  }
}


data "azurerm_virtual_network" "existing" {
  for_each = { for k, v in local.vnets_existing : k => v if var.enable_virtual_networks }
  name                = each.value.name
  resource_group_name = coalesce(try(each.value.resource_group_name, null), data.azurerm_resource_group.rg.name)
}



data "azurerm_subnet" "existing" {
  for_each = { for k, v in local.existing_subnets_flat : k => v if var.enable_virtual_networks }
  name                 = each.value.subnet_name
  resource_group_name  = each.value.rg_name
  virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
}

#--------------------------------------------------------------------
# 3) Create NSGs only for create_nsg=true
module "nsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.0"
  for_each       = { for k, v in local.nsg_create : k => v if var.enable_nsg }
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
  location            = coalesce(try(each.value.location, null), data.azurerm_resource_group.rg.location)
  tags                = try(each.value.tags, null)
  security_rules = try(local.nsg_security_rules[each.key], {})
  enable_telemetry = false
}

# 4) Lookup only for create_nsg=false
data "azurerm_network_security_group" "existing" {
  for_each       = { for k, v in local.nsg_lookup : k => v if var.enable_nsg }
  #for_each = local.nsg_lookup
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
}

output "nsg_ids" {
  value = local.nsg_ids
}

module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"
  for_each = { for k, v in local.keyvault_configs : k => v if var.enable_kv}

  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = each.value.soft_delete_retention_days
  purge_protection_enabled        = each.value.purge_protection_enabled
  legacy_access_policies_enabled  = each.value.legacy_access_policies_enabled
  enabled_for_deployment          = each.value.enabled_for_deployment
  enabled_for_disk_encryption     = each.value.enabled_for_disk_encryption
  enabled_for_template_deployment = each.value.enabled_for_template_deployment
  public_network_access_enabled   = each.value.public_network_access_enabled
  enable_telemetry                = false
  tags                            = try(each.value.tags, null)
  # ---- network ACLs: convert vnet/subnet refs -> subnet IDs ----
  network_acls = merge(
    try(each.value.network_acls, {}),
    {
      virtual_network_subnet_ids = [
        for r in try(each.value.network_acls.virtual_network_subnet_refs, []) :
        local.subnet_ids["${r.vnet_key}.${r.subnet_key}"]
      ]
    }
  )
  # ---- private endpoints: derive subnet_resource_id from vnet1.snet1 etc ----
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }

  diagnostic_settings = (
    contains(keys(each.value), "diagnostic_settings") && length(each.value.diagnostic_settings) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
      }
    }
    : null
  )
}


module "law" {
  source                                    = "Azure/avm-res-operationalinsights-workspace/azurerm"
  count                                     = var.enable_log_analytics_workspace ? 1 : 0
  version                                   = "0.4.2"
  name                                      = "IL-log-cind-test"
  location                                  = data.azurerm_resource_group.rg.location
  resource_group_name                       = data.azurerm_resource_group.rg.name
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = 30
  enable_telemetry                          = false
  tags = {
    created_by = "terraform"
  }
}