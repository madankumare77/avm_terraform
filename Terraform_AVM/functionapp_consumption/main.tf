
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
    ? {}
    : { for k, v in each.value.app_settings : k => tostring(v) }
  )
  site_config = {
    always_on         = try(each.value.site_config.always_on, null)
    application_stack = try(each.value.site_config.application_stack, null)
    application_insights_connection_string = module.avm-res-insights-component.connection_string
    application_insights_key = module.avm-res-insights-component.instrumentation_key
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

# module "avm-res-web-site" {
#   source   = "Azure/avm-res-web-site/azurerm"
#   version  = "0.19.1"
#   for_each = {
#     for k, v in local.function_app_configs : k => v
#   }

#   name                = each.value.name
#   location            = each.value.location
#   resource_group_name = each.value.resource_group_name

#   kind     = each.value.kind
#   os_type  = each.value.os_type
#   https_only = each.value.https_only

#   service_plan_resource_id = each.value.service_plan_resource_id

#   storage_account_name = each.value.storage_account_name

#   storage_account_access_key = try(
#     each.value.storage_account_access_key,
#     null
#   )

#   public_network_access_enabled = (
#     each.value.public_network_access_enabled
#   )

#   virtual_network_subnet_id = try(
#     each.value.virtual_network_subnet_id,
#     null
#   )

#   ftp_publish_basic_authentication_enabled = try(
#     each.value.ftp_publish_basic_authentication_enabled,
#     false
#   )

#   webdeploy_publish_basic_authentication_enabled = try(
#     each.value.webdeploy_publish_basic_authentication_enabled,
#     false
#   )

#   # The Application Insights resource is created separately.
#   enable_application_insights = false

#   application_insights_connection_string = (
#     module.avm-res-insights-component.connection_string
#   )

#   application_insights_key = (
#     module.avm-res-insights-component.instrumentation_key
#   )

#   # AVM module telemetry, not Function App application logging.
#   enable_telemetry = try(each.value.enable_telemetry, false)

#   # Flex Consumption
#   function_app_uses_fc1  = true
#   fc1_runtime_name       = each.value.fc1_runtime_name
#   fc1_runtime_version    = each.value.fc1_runtime_version
#   instance_memory_in_mb  = each.value.instance_memory_in_mb
#   maximum_instance_count = each.value.maximum_instance_count

#   storage_container_type = lower(
#     each.value.storage_container_type
#   )

#   storage_container_endpoint = (
#     each.value.storage_container_endpoint
#   )

#   storage_authentication_type = lower(
#     each.value.storage_authentication_type
#   )

#   storage_user_assigned_identity_id = try(
#     each.value.storage_user_assigned_identity_id,
#     null
#   )

#   app_settings = merge(
#     {
#       FUNCTIONS_EXTENSION_VERSION = "~4"
#     },
#     try(each.value.app_settings, {}) == null
#     ? {}
#     : {
#         for k, v in each.value.app_settings :
#         k => tostring(v)
#       }
#   )

#   site_config = {
#     always_on = try(
#       each.value.site_config.always_on,
#       null
#     )

#     minimum_tls_version = try(
#       each.value.site_config.minimum_tls_version,
#       "1.2"
#     )

#     scm_minimum_tls_version = try(
#       each.value.site_config.scm_minimum_tls_version,
#       "1.2"
#     )
#   }

#   diagnostic_settings = (
#     contains(keys(each.value), "diagnostic_settings") &&
#     length(each.value.diagnostic_settings) > 0
#     ? {
#         for diag_k, diag in each.value.diagnostic_settings :
#         diag_k => {
#           name = try(diag.name, null)

#           workspace_resource_id = try(
#             diag.workspace_resource_id,
#             null
#           )
#         }
#       }
#     : null
#   )

#   private_endpoints_manage_dns_zone_group = try(
#     each.value.private_endpoints_manage_dns_zone_group,
#     false
#   )

#   private_endpoints = {
#     for pe_key, pe in try(each.value.private_endpoints, {}) :
#     pe_key => {
#       name = try(pe.name, null)

#       subnet_resource_id = local.subnet_ids[
#         "${pe.vnet_key}.${pe.subnet_key}"
#       ]

#       private_dns_zone_resource_ids = try(
#         pe.private_dns_zone_resource_ids,
#         []
#       )

#       tags = try(pe.tags, null)
#     }
#   }

#   managed_identities = {
#     system_assigned = try(
#       each.value.managed_identities.system_assigned,
#       true
#     )

#     user_assigned_resource_ids = toset([
#       for id_key in try(
#         each.value.user_assigned_identity_keys,
#         []
#       ) :
#       module.avm-res-managedidentity-userassignedidentity[
#         id_key
#       ].resource_id
#     ])
#   }

#   tags = (
#     try(each.value.tags, null) == null
#     ? null
#     : {
#         for k, v in each.value.tags :
#         k => tostring(v)
#       }
#   )

#   depends_on = [
#     module.avm-res-storage-storageaccount,
#     module.avm-res-web-serverfarm,
#     module.avm-res-insights-component
#   ]
# }
 
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

# module "logic-app" {
#   source  = "Azure/avm-res-web-site/azurerm"
#   version = "0.22.0"

#   name = "mk-logicapp"
#   location = data.azurerm_resource_group.rg.location
#   parent_id = data.azurerm_resource_group.rg.id
#   kind = "logicapp"
#   service_plan_resource_id = azurerm_service_plan.example.id
#   storage_account_name = module.avm-res-storage-storageaccount["st_paas"].name
#   storage_account_access_key = data.azurerm_storage_account.sa.primary_access_key
#   enable_telemetry = false
#   diagnostic_settings = {
#     diag = {
#       name                  = "diag-logs"
#       workspace_resource_id = try(module.law.resource_id, null)
#     }
#   }
#   site_config = {
#     always_on         = true
#     application_insights_connection_string = module.avm-res-insights-component.connection_string
#     application_insights_key = module.avm-res-insights-component.instrumentation_key
#     # application_stack = {
#     #   dotnet = {
#     #     dotnet_version = "6.0"
#     #     use_dotnet_isolated_runtime = true
#     #   }
#     # }
#   }
#   depends_on = [ data.azurerm_storage_account.sa ]
# }

resource "azurerm_service_plan" "example" {
  name                = "mk-service-plan"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  os_type  = "Windows"
  sku_name = "WS1"
}

data "azurerm_storage_account" "sa" {
  name = module.avm-res-storage-storageaccount["st_paas"].name
  resource_group_name = data.azurerm_resource_group.rg.name
  depends_on = [ module.avm-res-storage-storageaccount ]
}

module "law" {
  source                                    = "Azure/avm-res-operationalinsights-workspace/azurerm"
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

module "avm-res-insights-component" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "0.4.0"

  name = "app-insights-mk"
  location                                  = data.azurerm_resource_group.rg.location
  resource_group_name                       = data.azurerm_resource_group.rg.name
  application_type                          = "web"
  workspace_id                              = module.law.resource_id
  enable_telemetry                          = false
}


locals {
  logic_app_configs = {
    logic1 = {
      name                                           = "logic-app01-test"
      location                                       = data.azurerm_resource_group.rg.location
      resource_group_name                            = data.azurerm_resource_group.rg.name
      parent_id                                      = data.azurerm_resource_group.rg.id
      kind                                           = "logicapp"
      os_type                                        = "Windows"
      https_only                                     = true
      service_plan_resource_id                       = try(azurerm_service_plan.example.id, null)
      public_network_access_enabled                  = false
      #virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      #vnet_route_all_traffic                         = true
      #vnet_content_share_enabled                     = true
      ftp_publish_basic_authentication_enabled       = false
      scm_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      system_assigned                                = false
      user_assigned_identity_keys                    = ["function"]
      storage_authentication_type                    = "UserAssignedIdentity"
      storage_user_assigned_identity_id             = try(module.avm-res-managedidentity-userassignedidentity["function"].resource_id, null)
      storage_account_name                           = module.avm-res-storage-storageaccount["st_paas"].name

 
      site_config = {
        always_on               = true
        minimum_tls_version     = "1.2"
        scm_minimum_tls_version = "1.2"
        ftps_state              = "Disabled"
        runtime_scale_monitoring_enabled = true
        application_insights_connection_string = module.avm-res-insights-component.connection_string
        application_insights_key = module.avm-res-insights-component.instrumentation_key
      }
      app_settings = {
        APP_KIND                                           = "workflowApp"
        FUNCTIONS_EXTENSION_VERSION                        = "~4"
        FUNCTIONS_WORKER_RUNTIME                           = "dotnet"
        WEBSITE_NODE_DEFAULT_VERSION                       = "~18"
        #WEBSITE_CONTENTSHARE                               = "logic-app-file-share-name"
        #WEBSITE_CONTENTAZUREFILECONNECTIONSTRING           = "@Microsoft.KeyVault(VaultName=<key_vault_name>;SecretName=<storage_file_connection_secret_name>)"
        WEBSITE_SKIP_CONTENTSHARE_VALIDATION               = "1"
        AzureWebJobsStorage                                = ""
        AzureWebJobsStorage__credentialType                = "managedIdentity"
        AzureWebJobsStorage__managedIdentityResourceId     = try(module.avm-res-managedidentity-userassignedidentity["function"].resource_id, null)
        AzureWebJobsStorage__blobServiceUri                = "https://${module.avm-res-storage-storageaccount["st_paas"].name}.blob.core.windows.net"
        AzureWebJobsStorage__queueServiceUri               = "https://${module.avm-res-storage-storageaccount["st_paas"].name}.queue.core.windows.net"
        AzureWebJobsStorage__tableServiceUri               = "https://${module.avm-res-storage-storageaccount["st_paas"].name}.table.core.windows.net"
      }
      diagnostic_settings = {
        diag = {
          name = "diag-logic-app01-test"
          workspace_resource_id = module.law.resource_id
          log_analytics_destination_type = "Dedicated"
          logs = [
            {
              category = "WorkflowRuntime"
              enabled = true
            },
            {
              category = "FunctionAppLogs"
              enabled = true
            },
            {
              category = "AppServiceAuthenticationLogs"
              enabled = true
            },
            {
              category = "AppServiceIPSecAuditLogs"
              enabled = true
            },
            {
              category = "AppServiceAuditLogs"
              enabled = true
            }
          ]
          metrics = [
            {
              category = "AllMetrics"
              enabled = true
            }
          ]
        }
      }
      #private_endpoints_manage_dns_zone_group = false
      # private_endpoints = {
      #   pe = {
      #     name                          = "pvt-endpoint-la-cind-iga-test"
      #     vnet_key                      = "vnet_paas"
      #     subnet_key                    = "snet_paas"
      #   }
      # }
      tags = {
        created_by = "terraform"
        INFY_EA_ResourceName = "la-cind-iga-test"
        INFY_EA_CustomTag01 = "No PO"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMPRJBE"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_Automation = "No"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_Purpose = "IS Internal"
        INFY_EA_Role = "Storage"
        INFY_EA_Technical_Tag = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_Workinghours  = "00 =00 23 =59"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_ProjectCode = "EPMPRJBE"
      }
    }
  }
}
 

module "logic_app" {
  source   = "Azure/avm-res-web-site/azurerm"
  version  = "0.22.0"
  for_each = local.logic_app_configs
 
  name                           = each.value.name
  location                       = each.value.location
  parent_id                      = each.value.parent_id
  kind                           = each.value.kind
  os_type                        = each.value.os_type
  https_only                     = each.value.https_only
  service_plan_resource_id       = each.value.service_plan_resource_id
  #virtual_network_subnet_id      = each.value.virtual_network_subnet_id
  #vnet_route_all_traffic         = each.value.vnet_route_all_traffic
  #vnet_content_share_enabled     = each.value.vnet_content_share_enabled
  public_network_access_enabled  = each.value.public_network_access_enabled
  #key_vault_reference_identity   = each.value.key_vault_reference_identity
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enabled
  scm_publish_basic_authentication_enabled       = each.value.scm_publish_basic_authentication_enabled
  enable_telemetry               = try(each.value.enable_telemetry, false)
  app_settings                   = each.value.app_settings
  site_config                    = each.value.site_config
  tags                           = each.value.tags
  storage_account_name           = each.value.storage_account_name
  storage_account_access_key     = data.azurerm_storage_account.sa.primary_access_key
  storage_authentication_type      = try(each.value.storage_authentication_type, null)  
  storage_user_assigned_identity_id  = try(each.value.storage_user_assigned_identity_id, null)
 
  managed_identities = {
    system_assigned = try(each.value.managed_identities.system_assigned, false)
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }
 
  #private_endpoints_manage_dns_zone_group = each.value.private_endpoints_manage_dns_zone_group
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }
  diagnostic_settings = try(each.value.diagnostic_settings, {})
  depends_on = [module.avm-res-storage-storageaccount, data.azurerm_storage_account.sa]
}