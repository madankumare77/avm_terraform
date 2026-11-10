data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"
}

locals {
  virtual_networks = {
    vnet_paas = {
      create_vnet            = true
      parent_id             = data.azurerm_resource_group.rg.id
      name                   = "vnet-infy-test"
      location               = data.azurerm_resource_group.rg.location
      address_space          = ["10.0.0.0/16"]
      enable_ddos_protection = false
      dns_servers            = ["168.63.129.16"]
      tags = {
        created_by = "terraform"
      }
      subnet_configs = {
        snet_pe = {
          name           = "subnet-pe"
          address_prefix = ["10.0.1.0/24"]
          service_endpoints = ["Microsoft.Web", "Microsoft.Storage"]
        }
        snet_func = {
          name              = "snet-function"
          address_prefix    = ["10.0.2.0/24"]
          service_endpoints = ["Microsoft.Web", "Microsoft.Storage"]
          delegation = {
            name = "flexconsumption"
            service_delegation = {
              name    = "Microsoft.App/environments"
              actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"  # use join for Flex Consumption Functions
              ]
            }
          }
        }
      }
    }
  }
}

 
#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    function = {
      name                = "function-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }
  }
}
 
#--------------------------------------------------------------------
# Virtual Network Locals to check the condition to create or use existing
#--------------------------------------------------------------------
locals {
  vnets_to_create = {
    for k, v in local.virtual_networks : k => v
    if try(v.create_vnet, true)
  }
 
  vnets_existing = {
    for k, v in local.virtual_networks : k => v
    if !try(v.create_vnet, true)
  }
}
locals {
  existing_subnets_flat = merge([
    for vnet_key, vnet in local.vnets_existing : {
      for subnet_key, subnet in try(vnet.existing_subnets, {}) :
      "${vnet_key}.${subnet_key}" => {
        vnet_key    = vnet_key
        subnet_key  = subnet_key
        subnet_name = subnet.name
        rg_name     = vnet.resource_group_name
      }
    }
  ]...)
}
locals {
  vnet_ids = merge(
    { for k, m in module.avm_res_network_virtualnetwork : k => m.resource_id },
    { for k, d in data.azurerm_virtual_network.existing : k => d.id }
  )
}
locals {
  created_subnet_ids = merge([
    for vnet_key, vnet_mod in module.avm_res_network_virtualnetwork : {
      for subnet_key, subnet_mod in vnet_mod.subnets :
      "${vnet_key}.${subnet_key}" => subnet_mod.resource_id
    }
  ]...)
 
  existing_subnet_ids = {
    for k, s in data.azurerm_subnet.existing : k => s.id
  }
 
  subnet_ids = merge(local.created_subnet_ids, local.existing_subnet_ids)
}
 
#--------------------------------------------------------------------
# Function App configurations
#--------------------------------------------------------------------
locals {
  function_app_configs = {
    function1 = {
      name                                           = "consumpotuion-function1"
      location                                       = data.azurerm_resource_group.rg.location
      resource_group_name                            = data.azurerm_resource_group.rg.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = true
      enable_application_insights                    = false
      function_app_uses_fc1 = true
      fc1_runtime_name      = "python"
      fc1_runtime_version   = "3.14"
      instance_memory_in_mb = 2048
      maximum_instance_count = 100
      storage_container_type      = "blobContainer"
      storage_container_endpoint  = "https://stcindmkfunction.blob.core.windows.net/func-container"
      storage_authentication_type = "SystemAssignedIdentity"
      #storage_user_assigned_identity_id   = try(module.avm-res-managedidentity-userassignedidentity["function"].resource_id, null)
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_func"], null)
      ftp_publish_basic_authentication_enabled       = true
      scm_publish_basic_authentication_enabled       = true
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        minimum_tls_version         = "1.2"
        scm_minimum_tls_version     = "1.2"
        app_insights_key            = "app_insights1"
        application_stack = {
          python = {
            python_version = "3.11"
            # dotnet_version = "10.0"
            # use_dotnet_isolated_runtime = true
             }
        }
      }
      app_settings = {
        FUNCTIONS_EXTENSION_VERSION = "~4"
        AzureWebJobsStorage__accountName = module.avm-res-storage-storageaccount["st_paas"].name
        AzureWebJobsStorage__credential = "managedidentity"
        AzureWebJobsStorage = ""
      }
      # diagnostic_settings = {
      #   diag = {
      #     name                  = "diag-logs"
      #     #target_resource_id             = 
      #     workspace_resource_id = try(module.law.resource_id, null)
      #   }
      # }
      private_endpoints_manage_dns_zone_group = false
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-utility-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_pe"
          #private_dns_zone_resource_ids = []
        }
      }
      tags = {
        created_by  = "terraform"
        INFY_EA_Automation = "Yes"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_CustomTag01 = "No PO"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMProjects"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_ProjectCode = "EPMPRJBE"
        INFY_EA_Purpose = "IS Internal"
        INFY_EA_ResourceName = "func-travel-utility-test"
        INFY_EA_Role = "Function App"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_Workinghours = "NA"
        app_os = "linux"
      }
    }
    # function1 = {
    #   name                = "consumption-function1"
    #   location            = data.azurerm_resource_group.rg.location
    #   resource_group_name = data.azurerm_resource_group.rg.name
    
    #   kind      = "functionapp"
    #   os_type   = "Linux"
    #   https_only = true
    
    #   service_plan_resource_id = try(
    #     module.avm-res-web-serverfarm["plan1"].resource_id,
    #     null
    #   )
    
    #   storage_account_name = try(
    #     module.avm-res-storage-storageaccount["st_paas"].name,
    #     null
    #   )
    
    #   public_network_access_enabled = false
    
    #   # Existing, separately managed Application Insights.
    #   enable_application_insights = false
    
    #   function_app_uses_fc1  = true
    #   fc1_runtime_name       = "python"
    #   fc1_runtime_version    = "3.11"
    #   instance_memory_in_mb  = 2048
    #   maximum_instance_count = 100
    
    #   storage_container_type = "blobcontainer"
    
    #   storage_container_endpoint = (
    #     azurerm_storage_container.function.id
    #   )
    
    #   storage_authentication_type = "systemassignedidentity"
    
    #   storage_user_assigned_identity_id = null
    
    #   virtual_network_subnet_id = try(
    #     local.subnet_ids["vnet_paas.snet_func"],
    #     null
    #   )
    
    #   ftp_publish_basic_authentication_enabled       = false
    #   webdeploy_publish_basic_authentication_enabled = false
    
    #   user_assigned_identity_keys = ["function"]
    
    #   enable_telemetry = false
    
    #   app_settings = {
    #     FUNCTIONS_EXTENSION_VERSION = "~4"
    #   }
    
    #   site_config = {
    #     minimum_tls_version     = "1.2"
    #     scm_minimum_tls_version = "1.2"
    #   }
    # }
    # function2 = {
    #   name                                           = "consumpotuion2-function"
    #   location                                       = data.azurerm_resource_group.rg.location
    #   resource_group_name                            = data.azurerm_resource_group.rg.name
    #   kind                                           = "functionapp"
    #   os_type                                        = "Linux"
    #   https_only                                     = true
    #   service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
    #   storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
    #   public_network_access_enabled                  = false
    #   enable_application_insights                    = false
    #   function_app_uses_fc1 = true
    #   fc1_runtime_name      = "dotnet-isolated"
    #   fc1_runtime_version   = "10.0"
    #   instance_memory_in_mb = 2048
    #   maximum_instance_count = 100
    #   storage_container_type      = "blobContainer"
    #   storage_container_endpoint  = azurerm_storage_container.example.id
    #   storage_authentication_type = "UserAssignedIdentity"
    #   storage_user_assigned_identity_id   = try(module.avm-res-managedidentity-userassignedidentity["function"].resource_id, null)
    #   virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_func"], null)
    #   ftp_publish_basic_authentication_enabled       = true
    #   scm_publish_basic_authentication_enabled       = true
    #   webdeploy_publish_basic_authentication_enabled = false
    #   user_assigned_identity_keys                    = ["function"]
    #   enable_telemetry                               = false
    #   site_config = {
    #     minimum_tls_version         = "1.2"
    #     scm_minimum_tls_version     = "1.2"
    #     app_insights_key            = "app_insights1"
    #     application_stack = {
    #       dotnet = {
    #         dotnet_version = "10.0"
    #         use_dotnet_isolated_runtime = true
    #          }
    #     }
    #   }
    #   # diagnostic_settings = {
    #   #   diag = {
    #   #     name                  = "diag-logs"
    #   #     workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
    #   #   }
    #   # }
    #   private_endpoints_manage_dns_zone_group = false
    #   private_endpoints = {
    #     functionpe = {
    #       name       = "pvt-endpoint-func-travel-utility-test"
    #       vnet_key   = "vnet_paas"
    #       subnet_key = "snet_pe"
    #       #private_dns_zone_resource_ids = []
    #     }
    #   }
    #   tags = {
    #     created_by  = "terraform"
    #     INFY_EA_Automation = "Yes"
    #     INFY_EA_BusinessUnit = "IS"
    #     INFY_EA_CostCenter = "No FR_IS"
    #     INFY_EA_CustomTag01 = "No PO"
    #     INFY_EA_CustomTag02 = "Infosys Limited"
    #     INFY_EA_CustomTag03 = "EPMProjects"
    #     INFY_EA_CustomTag04 = "PaaS"
    #     INFY_EA_ProjectCode = "EPMPRJBE"
    #     INFY_EA_Purpose = "IS Internal"
    #     INFY_EA_ResourceName = "func-travel-utility-test"
    #     INFY_EA_Role = "Function App"
    #     INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_WorkLoadType = "Test"
    #     INFY_EA_Workinghours = "NA"
    #     app_os = "linux"
    #   }
    # }
    # function3 = {
    #   name                                           = "app-service"
    #   location                                       = data.azurerm_resource_group.rg_paas.location
    #   resource_group_name                            = data.azurerm_resource_group.rg_paas.name
    #   kind                                           = "functionapp"
    #   os_type                                        = "Linux"
    #   https_only                                     = true
    #   service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
    #   storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
    #   #storage_account_access_key                     =
    #   public_network_access_enabled                  = false
    #   enable_application_insights                    = false
    #   virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
    #   ftp_publish_basic_authentication_enabled       = true
    #   scm_publish_basic_authentication_enabled       = true
    #   webdeploy_publish_basic_authentication_enabled = false
    #   user_assigned_identity_keys                    = ["function"]
    #   enable_telemetry                               = false
    #   site_config = {
    #     always_on                   = false
    #     minimum_tls_version         = "1.2"
    #     scm_minimum_tls_version     = "1.2"
    #     app_insights_key            = "app_insights1"
    #     application_stack = {
    #       dotnet = {
    #         dotnet_version = "10.0"
    #         use_dotnet_isolated_runtime = true
    #          }
    #     }
    #   }
    #   diagnostic_settings = {
    #     diag = {
    #       name                  = "diag-logs"
    #       workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
    #     }
    #   }
    #   private_endpoints_manage_dns_zone_group = false
    #   private_endpoints = {
    #     functionpe = {
    #       name       = "pvt-endpoint-func-travel-utility-test"
    #       vnet_key   = "vnet_paas"
    #       subnet_key = "snet_paas"
    #       #private_dns_zone_resource_ids = []
    #     }
    #   }
    #   tags = {
    #     created_by  = "terraform"
    #     INFY_EA_Automation = "Yes"
    #     INFY_EA_BusinessUnit = "IS"
    #     INFY_EA_CostCenter = "No FR_IS"
    #     INFY_EA_CustomTag01 = "No PO"
    #     INFY_EA_CustomTag02 = "Infosys Limited"
    #     INFY_EA_CustomTag03 = "EPMProjects"
    #     INFY_EA_CustomTag04 = "PaaS"
    #     INFY_EA_ProjectCode = "EPMPRJBE"
    #     INFY_EA_Purpose = "IS Internal"
    #     INFY_EA_ResourceName = "func-travel-utility-test"
    #     INFY_EA_Role = "Function App"
    #     INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_WorkLoadType = "Test"
    #     INFY_EA_Workinghours = "NA"
    #     app_os = "linux"
    #   }
    # }
  }
}
#--------------------------------------------------------------------
# App Service Plan configurations
#--------------------------------------------------------------------
locals {
  app_service_plan = {
    plan1 = {
      name                = "asp-consumption-test"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      sku_name            = "FC1"
      os_type             = "Linux"
      # maximum_elastic_worker_count = 20
      zone_balancing_enabled = false
      enable_telemetry    = false
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }
    }
  }
}
 
#--------------------------------------------------------------------
# #Storage Account configurations
#--------------------------------------------------------------------
locals {
  storage_account_configs = {
    st_paas = {
      name                              = "stcindmkfunction"
      resource_group_name               = data.azurerm_resource_group.rg.name
      location                          = data.azurerm_resource_group.rg.location
      account_tier                      = "Standard"
      account_replication_type          = "LRS"
      access_tier                       = "Hot"
      account_kind                      = "StorageV2"
      allow_nested_items_to_be_public   = false
      default_to_oauth_authentication   = true
      https_traffic_only_enabled        = true
      infrastructure_encryption_enabled = true
      local_user_enabled                = false
      min_tls_version                   = "TLS1_2"
      public_network_access_enabled     = false
      sftp_enabled                      = false
      shared_access_key_enabled         = false
      enable_telemetry                  = false
      blob_properties = {
        versioning_enabled            = false
        container_delete_retention_policy = {
          enabled = true
          days    = 7
        }
        delete_retention_policy = {
          days = 7
          permanent_delete_enabled = true
        }
      }
      network_rules_subnet_refs = [
        {
          vnet_key   = "vnet_paas"
          subnet_key = "snet_pe"
        }
      ]
      # diagnostic_settings = {
      #   diag = {
      #     name                  = "diag-logs"
      #     workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
      #   }
      # }
      private_endpoints_manage_dns_zone_group = false
      private_endpoints = {
        stpe = {
          name                          = "pvt-endpoint-stcindtraveltest"
          vnet_key                      = "vnet_paas"
          subnet_key                    = "snet_pe"
          subresource_name              = "blob"
          tags                          = { env = "test" }
        }
      }
      tags = {
        created_by = "terraform"
        INFY_EA_ResourceName = "stcindtraveltest"
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
