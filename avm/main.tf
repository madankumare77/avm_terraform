

data "azurerm_resource_group" "rg" {
  name = "madan-test"
}
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
module "avm_res_network_virtualnetwork" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.16.0"
  for_each = { for k, v in local.vnets_to_create : k => v if var.enable_virtual_networks }
  #for_each = local.vnets_to_create

  name      = each.value.name
  location  = each.value.location
  parent_id = data.azurerm_resource_group.rg.id

  address_space = each.value.address_space

  enable_telemetry = false
  dns_servers      = (try(each.value.dns_servers, null) == null ? null : { dns_servers = each.value.dns_servers })
  # --- Transform your subnet_configs -> module.subnets expected shape ---
  subnets = {
    for sk, s in each.value.subnet_configs : sk => {
      name             = s.name
      address_prefixes = s.address_prefix
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
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

data "azurerm_virtual_network" "existing" {
  for_each            = { for k, v in local.vnets_existing : k => v if var.enable_virtual_networks }
  name                = each.value.name
  resource_group_name = coalesce(try(each.value.resource_group_name, null), data.azurerm_resource_group.rg.name)
}
data "azurerm_subnet" "existing" {
  for_each             = { for k, v in local.existing_subnets_flat : k => v if var.enable_virtual_networks }
  name                 = each.value.subnet_name
  resource_group_name  = each.value.rg_name
  virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
}

#--------------------------------------------------------------------
# Network Security Group
#--------------------------------------------------------------------
module "nsg" {
  source              = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version             = "0.5.0"
  for_each            = { for k, v in local.nsg_create : k => v if var.enable_nsg }
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
  location            = coalesce(try(each.value.location, null), data.azurerm_resource_group.rg.location)
  security_rules      = try(local.nsg_security_rules[each.key], {})
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
# 4) Lookup only for create_nsg=false
data "azurerm_network_security_group" "existing" {
  for_each            = { for k, v in local.nsg_lookup : k => v if var.enable_nsg }
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
}
output "nsg_ids" {
  value = local.nsg_ids
}

#--------------------------------------------------------------------
#Key Vault
#--------------------------------------------------------------------
module "keyvault" {
  source   = "Azure/avm-res-keyvault-vault/azurerm"
  version  = "0.10.2"
  for_each = { for k, v in local.keyvault_configs : k => v if var.enable_kv }

  name                            = each.value.name
  location                        = each.value.location
  resource_group_name             = each.value.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
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

#--------------------------------------------------------------------
# #Storage Account
#--------------------------------------------------------------------
module "avm-res-storage-storageaccount" {
  source                            = "Azure/avm-res-storage-storageaccount/azurerm"
  for_each                          = { for k, v in local.storage_account_configs : k => v if var.enable_storage_account }
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

  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      subresource_name              = pe.subresource_name
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }

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

#--------------------------------------------------------------------
# Function App
#--------------------------------------------------------------------
module "avm-res-web-site" {
  source                                         = "Azure/avm-res-web-site/azurerm"
  for_each                                       = { for k, v in local.function_app_configs : k => v if var.enable_function_app }
  version                                        = "0.19.1"
  name                                           = each.value.name
  location                                       = each.value.location
  resource_group_name                            = each.value.resource_group_name
  kind                                           = each.value.kind
  os_type                                        = each.value.os_type
  https_only                                     = each.value.https_only
  service_plan_resource_id                       = each.value.service_plan_resource_id #module.avm-res-web-serverfarm.resource_id
  storage_account_name                           = each.value.storage_account_name     #module.avm-res-storage-storageaccount["st1"].name
  public_network_access_enabled                  = each.value.public_network_access_enabled
  enable_application_insights                    = each.value.enable_application_insights
  virtual_network_subnet_id                      = each.value.virtual_network_subnet_id
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = each.value.webdeploy_publish_basic_authentication_enabled
  enable_telemetry                               = each.value.enable_telemetry
  app_settings = (
    try(each.value.app_settings, null) == null
    ? null
    : { for k, v in each.value.app_settings : k => tostring(v) }
  )
  site_config = {
    always_on         = try(each.value.site_config.always_on, null)
    application_stack = try(each.value.site_config.application_stack, null)

    application_insights_connection_string = (
      each.value.enable_application_insights == false
      ? module.avm-res-insights-component[each.value.site_config.app_insights_key].connection_string
      : null
    )

    application_insights_key = (
      each.value.enable_application_insights == false
      ? module.avm-res-insights-component[each.value.site_config.app_insights_key].instrumentation_key
      : null
    )
  }

  managed_identities = {
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
  for_each            = { for k, v in local.app_service_plan : k => v if var.enable_app_service_plan }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  sku_name            = each.value.sku_name
  os_type             = each.value.os_type
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
module "avm-res-managedidentity-userassignedidentity" {
  source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version             = "0.3.4"
  for_each            = { for k, v in local.user_assigned_identities : k => v if var.enable_user_assigned_identities }
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
# Application Insights
#--------------------------------------------------------------------
module "avm-res-insights-component" {
  source              = "Azure/avm-res-insights-component/azurerm"
  version             = "0.2.0"
  for_each            = { for k, v in local.app_insights_configs : k => v if var.enable_application_insights }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  workspace_id        = each.value.workspace_id
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

#--------------------------------------------------------------------
# AML Workspace
#--------------------------------------------------------------------
module "avm-res-machinelearningservices-workspace" {
  source                        = "Azure/avm-res-machinelearningservices-workspace/azurerm"
  version                       = "0.9.0"
  for_each                      = { for k, v in local.aml_workspace : k => v if var.enable_aml_workspace }
  name                          = each.value.name
  location                      = each.value.location
  resource_group_name           = each.value.resource_group_name
  enable_telemetry              = each.value.enable_telemetry
  public_network_access_enabled = each.value.public_network_access_enabled
  application_insights = {
    resource_id = module.avm-res-insights-component[each.value.application_insights_key].resource_id
  }
  key_vault = {
    resource_id = module.keyvault[each.value.key_vault_key].resource_id
  }
  storage_account = {
    resource_id = module.avm-res-storage-storageaccount[each.value.storage_account_key].resource_id
  }
  managed_identities = {
    system_assigned = try(each.value.managed_identities.system_assigned, false)
  }
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                            = try(pe.name, null)
      subnet_resource_id              = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids   = try(pe.private_dns_zone_resource_ids, [])
      private_service_connection_name = try(pe.name, null)
      tags                            = try(pe.tags, null)
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
  workspace_managed_network = try(each.value.workspace_managed_network, null)
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
  depends_on = [module.avm-res-insights-component, module.keyvault, module.avm-res-storage-storageaccount, module.law]
}

locals {
  cognitiveservices = {
    di1 = {
      enable_account = true
      name      = "di-claims-test-001"
      parent_id = data.azurerm_resource_group.rg.id
      location  = data.azurerm_resource_group.rg.location
      sku_name  = "S0"
      kind      = "FormRecognizer"
      enable_telemetry = false
      local_auth_enabled = false
      public_network_access_enabled = false
      private_endpoints = {
        di_pe = {
          name       = "pvt-endpoint-di-claims-test-poc"
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
          # If you already have private DNS zone ids, place them here; otherwise keep empty.
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-di-claims-test-001"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
    openai = {
      enable_account = true
      name      = "cind-oai-claims-test12"
      parent_id = data.azurerm_resource_group.rg.id
      location  = "South India"
      sku_name  = "S0"
      kind      = "OpenAI"
      enable_telemetry = false
      local_auth_enabled = false
      public_network_access_enabled = false
      private_endpoints = {
        openai_pe = {
          name       = "pvt-endpoint-cind-oai-claims-test12"
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
          location   = data.azurerm_resource_group.rg.location
          # If you already have private DNS zone ids, place them here; otherwise keep empty.
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        openai_diag = {
          name                  = "diag-cind-oai-claims-test12"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
  }
}

module "avm-res-cognitiveservices-account" {
  source                = "Azure/avm-res-cognitiveservices-account/azurerm"
  for_each              = { for k, v in local.cognitiveservices : k => v if var.enable_cognitiveservices && v.enable_account }
  version               = "0.10.2"
  name                  = each.value.name
  parent_id             = each.value.parent_id
  location              = each.value.location
  sku_name              = each.value.sku_name
  kind                  = each.value.kind
  local_auth_enabled    = each.value.local_auth_enabled
  public_network_access_enabled = each.value.public_network_access_enabled
  custom_subdomain_name = try(each.value.custom_subdomain_name, each.value.name)
  enable_telemetry              = each.value.enable_telemetry
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      location                      = try(pe.location, each.value.location)
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