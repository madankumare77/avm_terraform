
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
 
 
 
module "avm-res-managedidentity-userassignedidentity" {
  source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version             = "0.3.4"
  for_each            = { for k, v in local.user_assigned_identities : k => v }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}


#--------------------------------------------------------------------
# Function App
#--------------------------------------------------------------------
module "avm-res-web-site" {
  source                                         = "Azure/avm-res-web-site/azurerm"
  for_each                                       = { for k, v in local.function_app_configs : k => v }
  version                                        = "0.19.1"
  name                                           = each.value.name
  location                                       = each.value.location
  resource_group_name                            = each.value.resource_group_name
  kind                                           = each.value.kind
  os_type                                        = each.value.os_type
  https_only                                     = each.value.https_only
  service_plan_resource_id                       = each.value.service_plan_resource_id #module.avm-res-web-serverfarm.resource_id
  storage_account_name                           = each.value.storage_account_name     #module.avm-res-storage-storageaccount["st1"].name
  storage_account_access_key                     = try(each.value.storage_account_access_key, null) #module.avm-res-storage-storageaccount["st1"].primary_access_key
  public_network_access_enabled                  = each.value.public_network_access_enabled
  enable_application_insights                    = each.value.enable_application_insights
  virtual_network_subnet_id                      = each.value.virtual_network_subnet_id
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = each.value.webdeploy_publish_basic_authentication_enabled
  enable_telemetry                               = each.value.enable_telemetry

  function_app_uses_fc1 = try(each.value.function_app_uses_fc1, false)
  fc1_runtime_name      = try(each.value.fc1_runtime_name, null)
  fc1_runtime_version   = try(each.value.fc1_runtime_version, null)
  instance_memory_in_mb = try(each.value.instance_memory_in_mb, null)
  maximum_instance_count = try(each.value.maximum_instance_count, null)
  storage_container_type      = try(each.value.storage_container_type, null)
  storage_container_endpoint  = try(each.value.storage_container_endpoint, null)
  storage_authentication_type = try(each.value.storage_authentication_type, null)
  storage_user_assigned_identity_id   = try(each.value.storage_user_assigned_identity_id, null)

  app_settings = (
    try(each.value.app_settings, null) == null
    ? null
    : { for k, v in each.value.app_settings : k => tostring(v) }
  )
  site_config = {
    always_on         = try(each.value.site_config.always_on, null)
    application_stack = try(each.value.site_config.application_stack, null)
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
 
  # ---- private endpoints: derive subnet_resource_id from vnet1.snet1 etc ----
  private_endpoints_manage_dns_zone_group = try(each.value.private_endpoints_manage_dns_zone_group, false)
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }
  managed_identities = {
    system_assigned = try(each.value.managed_identities.system_assigned, true)
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }
 
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
  depends_on = [module.avm-res-storage-storageaccount, module.avm-res-web-serverfarm]
}
 
#--------------------------------------------------------------------
# App Service Plan
#--------------------------------------------------------------------
module "avm-res-web-serverfarm" {
  source              = "Azure/avm-res-web-serverfarm/azurerm"
  version             = "1.0.0"
  for_each            = { for k, v in local.app_service_plan : k => v }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  sku_name            = each.value.sku_name
  os_type             = each.value.os_type
  # maximum_elastic_worker_count = each.value.maximum_elastic_worker_count
  zone_balancing_enabled = each.value.zone_balancing_enabled
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
 
#--------------------------------------------------------------------
# #Storage Account
#--------------------------------------------------------------------
module "avm-res-storage-storageaccount" {
  source                            = "Azure/avm-res-storage-storageaccount/azurerm"
  for_each                          = { for k, v in local.storage_account_configs : k => v }
  version                           = "0.6.7"
  account_replication_type          = each.value.account_replication_type
  account_tier                      = each.value.account_tier
  location                          = each.value.location
  name                              = each.value.name
  resource_group_name               = each.value.resource_group_name
  access_tier                       = each.value.access_tier
  account_kind                      = each.value.account_kind
  allow_nested_items_to_be_public   = each.value.allow_nested_items_to_be_public
  default_to_oauth_authentication   = each.value.default_to_oauth_authentication
  https_traffic_only_enabled        = each.value.https_traffic_only_enabled
  infrastructure_encryption_enabled = each.value.infrastructure_encryption_enabled
  enable_telemetry                  = each.value.enable_telemetry
  local_user_enabled                = each.value.local_user_enabled
  min_tls_version                   = each.value.min_tls_version
  public_network_access_enabled     = each.value.public_network_access_enabled
  sftp_enabled                      = each.value.sftp_enabled
  shared_access_key_enabled         = each.value.shared_access_key_enabled
  network_rules = (
    length(try(each.value.network_rules_subnet_refs, [])) == 0
    ? null
    : {
      # optional - you can add default_action/bypass here if your module expects it
      virtual_network_subnet_ids = [
        for r in each.value.network_rules_subnet_refs :
        local.subnet_ids["${r.vnet_key}.${r.subnet_key}"]
      ]
    }
  )

  managed_identities = {
    # Identities can only be used with the Standard SKU
    system_assigned = true
    user_assigned_resource_ids = [
      module.avm-res-managedidentity-userassignedidentity["function"].resource_id
    ]
  }
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
  blob_properties = (
    try(each.value.blob_properties, null) == null
    ? null
    : {
      change_feed_enabled           = try(each.value.blob_properties.change_feed_enabled, null)
      change_feed_retention_in_days = try(each.value.blob_properties.change_feed_retention_in_days, null)
      default_service_version       = try(each.value.blob_properties.default_service_version, null)
      last_access_time_enabled      = try(each.value.blob_properties.last_access_time_enabled, null)
      versioning_enabled            = try(each.value.blob_properties.versioning_enabled, null)
 
      delete_retention_policy = (try(each.value.blob_properties.delete_retention_policy, null) == null ? null : {
        days = each.value.blob_properties.delete_retention_policy.days
        permanent_delete_enabled = each.value.blob_properties.delete_retention_policy.permanent_delete_enabled
      })
      container_delete_retention_policy = (try(each.value.blob_properties.container_delete_retention_policy, null) == null ? null : {
        days = each.value.blob_properties.container_delete_retention_policy.days
        #enabled = each.value.blob_properties.container_delete_retention_policy.enabled
      })
    }
  )
 
  immutability_policy = (
    try(each.value.immutability_policy, null) == null
    ? null
    : {
      state         = each.value.immutability_policy.state
      period_since_creation_in_days = each.value.immutability_policy.period_since_creation_in_days
      allow_protected_append_writes = each.value.immutability_policy.allow_protected_append_writes
    }
  )
 
  diagnostic_settings_blob = (
    contains(keys(each.value), "diagnostic_settings_blob") && length(each.value.diagnostic_settings_blob) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings_blob :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
        metric_categories     = try(toset(diag.metric_categories), null)
      }
    }
    : null
  )
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

resource "azurerm_storage_container" "example" {
  name                  = "func-container"
  storage_account_id    = module.avm-res-storage-storageaccount["st_paas"].resource_id
  container_access_type = "private"
}


#--------------------------------------------------------------------
#Key Vault
#--------------------------------------------------------------------
module "keyvault" {
  source   = "Azure/avm-res-keyvault-vault/azurerm"
  version  = "0.10.2"
  for_each = { for k, v in local.keyvault_configs : k => v }
 
  name                            = each.value.name
  location                        = each.value.location
  resource_group_name             = each.value.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = each.value.sku_name
  soft_delete_retention_days      = each.value.soft_delete_retention_days
  purge_protection_enabled        = each.value.purge_protection_enabled
  legacy_access_policies_enabled  = each.value.legacy_access_policies_enabled
  enabled_for_deployment          = each.value.enabled_for_deployment
  enabled_for_disk_encryption     = each.value.enabled_for_disk_encryption
  enabled_for_template_deployment = each.value.enabled_for_template_deployment
  public_network_access_enabled   = each.value.public_network_access_enabled
  enable_telemetry                = false
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
  private_endpoints_manage_dns_zone_group = try(each.value.private_endpoints_manage_dns_zone_group, false)
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
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}