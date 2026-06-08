data "azurerm_resource_group" "rg_sqlmi" {
  name = "rg-cind-sql-bcms-prod"   #contributor
}
 
data "azurerm_resource_group" "rg_sqlmi_vnet" {
  name = "rg-cind-mgmt"     #reader, but vnet contributor at scope of vnet
}
 
# Data block to reference an existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "law" {
  name                = "IL-InformationSystems-SQLMI-prod" # rbac administrator, Log Analytics Contributor()
  resource_group_name = "rg-cind-mgmt"  #Reader
}
 
data "azuread_group" "ad_group" {
display_name   = "IS-EPMDBProjects"
security_enabled = true             #Directory reader
}
 
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
module "avm_res_network_virtualnetwork" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.16.0"
  for_each = { for k, v in local.vnets_to_create : k => v }
  #for_each = local.vnets_to_create
  name      = each.value.name
  location  = each.value.location
  parent_id = each.value.parent_id
  address_space = each.value.address_space
  enable_telemetry = false
  dns_servers      = (try(each.value.dns_servers, null) == null ? null : { dns_servers = each.value.dns_servers })
  # --- Transform your subnet_configs -> module.subnets expected shape ---
  subnets = {
    for sk, s in each.value.subnet_configs : sk => {
      name             = s.name
      address_prefixes = s.address_prefix
      default_outbound_access_enabled = try(s.default_outbound_access_enabled, true)
      service_endpoints_with_location = [
        for svc in try(s.service_endpoints, []) : {
          service = svc
          # locations = [each.value.location] # use only if you want location restriction
        }
      ]
      #network_security_group = try((try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] }), null)
      #route_table = try(s.route_table, null)
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
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
 
data "azurerm_virtual_network" "existing" {
  for_each            = { for k, v in local.vnets_existing : k => v }
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}
data "azurerm_subnet" "existing" {
  for_each             = { for k, v in local.existing_subnets_flat : k => v }
  name                 = each.value.subnet_name
  resource_group_name  = each.value.rg_name
  virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
}
 
module "sqlmi" {
  source = "Azure/avm-res-sql-managedinstance/azurerm"
  version = "0.1.3"
  for_each = { for k, v in local.sqlmi-configs-secondary : k => v }
 
  name                         = each.value.name
  location                     = each.value.location
  administrator_login          = each.value.administrator_login
  administrator_login_password = each.value.administrator_login_password
  resource_group_name          = each.value.resource_group_name
  sku_name                     = each.value.sku_name
  vcores                       = each.value.vcores
  storage_size_in_gb           = each.value.storage_size_in_gb
  license_type                 = each.value.license_type
  timezone_id                  = each.value.timezone_id
  proxy_override               = each.value.proxy_override
  public_data_endpoint_enabled = each.value.public_data_endpoint_enabled
  subnet_id                    = each.value.subnet_id
  minimum_tls_version          = each.value.minimum_tls_version
  zone_redundant_enabled = each.value.zone_redundant_enabled
  storage_account_type = each.value.storage_account_type
  enable_telemetry    = false
  dns_zone_partner_id = try(each.value.dns_zone_partner_id, null)
  managed_identities = {
    system_assigned = try(each.value.managed_identities.system_assigned, false)
  }
  # managed_identities = {
  #   user_assigned_resource_ids = toset([
  #     for id_key in try(each.value.user_assigned_identity_keys, []) :
  #     module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
  #   ])
  # }
 
  active_directory_administrator = (
    try(each.value.active_directory_administrator, null) == null
    ? null
    : {
        azuread_authentication_only = each.value.active_directory_administrator.azuread_authentication_only
        object_id                   = each.value.active_directory_administrator.object_id
        tenant_id                   = each.value.active_directory_administrator.tenant_id
        login_username              = each.value.active_directory_administrator.login_username
      }
  )
 
  private_endpoints_manage_dns_zone_group = try(each.value.private_endpoints_manage_dns_zone_group, false)
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      subresource_name              = pe.subresource_name
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
        log_analytics_destination_type = "AzureDiagnostics"
      }
    }
    : null
  )
}