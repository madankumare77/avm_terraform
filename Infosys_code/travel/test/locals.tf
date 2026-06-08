locals {
  virtual_networks = {
    vnet_aks = {
      create_vnet         = false
      name                = "vnet-cind-itravel-test"
      resource_group_name = data.azurerm_resource_group.rg_vnet.name
 
      existing_subnets = {
        snet_aks = { name = "snet-cind-itravel-test" }
      }
    }
     vnet_paas = {
      create_vnet         = false
      name                = "vnet-cind-paas-internal-test-02"
      resource_group_name = data.azurerm_resource_group.rg_vnet_paas.name
 
      existing_subnets = {
        snet_paas     = { name = "snet-cind-pvt-test" }
        snet_function = { name = "snet-cind-func-travel-test" }
      }
    }
    vnet_apim = {
      create_vnet         = false
      name                = "vnet-cind-travel-apim-test"
      resource_group_name = data.azurerm_resource_group.rg_apim.name
 
      existing_subnets = {
        snet_apim     = { name = "snet-cind-apim-test" }
      }
    }
  }
}
 
#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
    nsg_apim = {
      create_nsg = true
      nsg_name   = "apim-cind-travel-apps-test-nsg"
      location   = data.azurerm_resource_group.rg_apim.location
      rg_name    = data.azurerm_resource_group.rg_apim.name
 
      security_rules = [
        # -------------------------------------------------
        # Inbound rules
        # -------------------------------------------------
     
        # Client communication to APIM
        {
          name                       = "Allow-Client-HTTP-HTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_ranges    = ["80", "443"]
          source_address_prefix      = "Internet"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # APIM management endpoint
        {
          name                       = "Allow-APIM-Management-3443"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "3443"
          source_address_prefix      = "ApiManagement"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # Azure Load Balancer – infrastructure
        {
          name                       = "Allow-AzureLoadBalancer-6390"
          priority                   = 120
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "6390"
          source_address_prefix      = "AzureLoadBalancer"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # Azure Traffic Manager (multi-region)
        {
          name                       = "Allow-TrafficManager-443"
          priority                   = 130
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "AzureTrafficManager"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # Machine health monitoring
        {
          name                       = "Allow-AzureLoadBalancer-6391"
          priority                   = 140
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "6391"
          source_address_prefix      = "AzureLoadBalancer"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # -------------------------------------------------
        # Outbound rules
        # -------------------------------------------------
     
        # Certificate validation
        {
          name                       = "Allow-Out-Cert-Validation"
          priority                   = 200
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "Internet"
        },
     
        # Azure Storage
        {
          name                       = "Allow-Out-Storage-443"
          priority                   = 210
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "Storage"
        },
     
        # Entra ID / Microsoft Graph / Key Vault dependency
        {
          name                       = "Allow-Out-AzureAD-443"
          priority                   = 220
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "AzureActiveDirectory"
        },
     
        # Managed connectors
        {
          name                       = "Allow-Out-AzureConnectors-443"
          priority                   = 230
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "AzureConnectors"
        },
     
        # Azure SQL
        {
          name                       = "Allow-Out-SQL-1433"
          priority                   = 240
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "1433"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "Sql"
        },
     
        # Azure Key Vault
        {
          name                       = "Allow-Out-KeyVault-443"
          priority                   = 250
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "AzureKeyVault"
        },
     
        # Event Hub (logs)
        {
          name                       = "Allow-Out-EventHub"
          priority                   = 260
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_ranges    = ["443", "5671", "5672"]
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "EventHub"
        },
     
        # Azure Monitor
        {
          name                       = "Allow-Out-AzureMonitor"
          priority                   = 270
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_ranges    = ["443", "1886"]
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "AzureMonitor"
        },
     
        # -------------------------------------------------
        # Internal APIM sync / Redis (optional)
        # -------------------------------------------------
     
        # Redis external
        {
          name                       = "Allow-Redis-6380"
          priority                   = 300
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "6380"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # Redis internal
        {
          name                       = "Allow-Redis-Internal"
          priority                   = 310
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_ranges    = ["6381", "6382", "6383"]
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
     
        # Rate limit sync
        {
          name                       = "Allow-RateLimit-Sync"
          priority                   = 320
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Udp"
          source_port_range          = "*"
          destination_port_range     = "4290"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        }
      ]
      tags = {
        created_by = "terraform"
        INFY_EA_Automation = "Yes"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_CustomTag01 = "No PO"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMProjects"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_ProjectCode = "EPMPRJBE"
        INFY_EA_Purpose = "IS Internal"
        INFY_EA_ResourceName = "apim-cind-travel-apps-test-nsg"
        INFY_EA_Role = "network sequrity group"
        INFY_EA_Technical_Tags = "EPM-Cloud@infosys.com"
        INFY_EA_WorkLoadType = "Test"
      }
    }
  }
}
 
#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    aks = {
      name                = "useridentity-isinfytravel-test"
      location            = data.azurerm_resource_group.rg_aks.location
      resource_group_name = data.azurerm_resource_group.rg_aks.name
    }
    function = {
      name                = "useridentity-function-cind-travel-test"
      location            = data.azurerm_resource_group.rg_paas.location
      resource_group_name = data.azurerm_resource_group.rg_paas.name
    }
  }
}
 
#--------------------------------------------------------------------
# Private DNS zone avm module to create and data block to use existing.
#--------------------------------------------------------------------
locals {
  private_dns_zones = {
    aks = {
      create_private_dns_zone = true
      private_dns_zone_name = "isinfytravel-test.privatelink.centralindia.azmk8s.io"
      parent_id = data.azurerm_resource_group.rg_aks.id
      vnet_id               = try(local.vnet_ids["vnet_aks"], null)
    }
  }
  private_dns_ids = merge(
    { for k, m in module.avm-res-network-privatednszone : k => m.resource_id },
    #{ for k, d in data.azurerm_private_dns_zone.existing : k => d.id }
  )
}
 
#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
locals {
  aks_configs = {
    aks_travel = {
      name = "isinfytravel-test"
      resource_group_name = data.azurerm_resource_group.rg_aks.name
      location = data.azurerm_resource_group.rg_aks.location
      node_resource_group_name   = "rg-aks-assets-isinfytravel-test"
     # kubernetes_version         = "1.35.1"  
      sku_tier                   = "Standard"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = false
      http_application_routing_enabled = false  #Since we are using istio ingress gateway application routing not required
      node_os_channel_upgrade    = "None"
      dns_prefix = "isinfytravel-test"
      local_account_disabled = true
      user_assigned_identity_keys                    = ["aks"]
      private_cluster_enabled    = true                    # force replacement of the cluster if changed
      role_based_access_control_enabled = true                      # force replacement of the cluster if changed
      disk_encryption_set_id = azurerm_disk_encryption_set.example.id
      azure_active_directory_role_based_access_control = {
        tenant_id = data.azurerm_client_config.current.tenant_id
        admin_group_object_ids = try([data.azuread_group.ad_group.object_id], null)
        azure_rbac_enabled = false                         # (false uses Microsoft entra ID authentication with kubernetes RBAC)
      }
      default_node_pool = {
        name            = "platform"
        vm_size         = "Standard_D4ds_v5"
        os_sku          = "AzureLinux"     #AzureLinux
        os_disk_size_gb = 130
        os_disk_type    = "Ephemeral"
        zones           = ["1", "2", "3"]  #South india not supporting for availability zones
        min_count            = 1
        type                 = "VirtualMachineScaleSets"
        max_count            = 3
        auto_scaling_enabled = true
        max_pods             = 90
        only_critical_addons_enabled  = true
        vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
        node_taints          = ["CriticalAddonsOnly=true:NoSchedule"]
      }
      node_pools = {
        np1 = {
          name    = "infytravel"
          vm_size = "Standard_F8s_v2"
          mode    = "User"
          min_count            = 1
          max_count            = 3
          auto_scaling_enabled = true
          zones           = ["1", "2", "3"]
          vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
          os_sku               = "AzureLinux"
          os_type              = "Linux"
          os_disk_size_gb      = 120
          os_disk_type         = "Ephemeral"
          max_pods             = 90
          node_labels = {
            "app" = "infytravel"
          }
          node_taints          = ["node=infytravel:NoSchedule"]
        }
      }
      network_profile = {
        network_plugin      = "azure"
        network_policy      = "cilium"
        network_data_plane  = "cilium"  
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.0.0.10"
        service_cidr        = "10.0.0.0/16"
        pod_cidr            = "192.168.0.0/16"
        outbound_type     = "userDefinedRouting"
        load_balancer_sku = "standard"
      }
      oms_agent = {
        log_analytics_workspace_id = try(data.azurerm_log_analytics_workspace.law.id, null)
        msi_auth_for_monitoring_enabled = true
      }
      service_mesh_profile = {
        mode = "Istio"
        revisions = ["asm-1-28"]
        external_ingress_gateway_enabled = false
        internal_ingress_gateway_enabled = false
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-aks-logs"
          storage_account_resource_id = data.azurerm_storage_account.aks_diag_st.id
        }
      }
      tags = {
        created_by  = "terraform"
        INFY_Appmaster_App_Name = "isinfytravel-test"
        INFY_Appmaster_ID = "NA"
        INFY_BusinessUnit = "IS"
        INFY_CostCenter = "No FR_IS"
        INFY_Environment = "Test"
        INFY_Managed_by = "IS"
        INFY_Owner = "EPM-Cloud@infosys.com"
        INFY_Platform = "Test"
        INFY_ProjectCode = "EPMPRJBE"
        INFY_Provider = "Azure"
      }
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
# NSG Locals to check the condition to create or use existing
#--------------------------------------------------------------------
locals {
  # 1) Split: create vs lookup
  nsg_create = {
    for k, v in local.nsg_configs : k => v
    if try(v.create_nsg, true)
  }
 
  nsg_lookup = {
    for k, v in local.nsg_configs : k => v
    if !try(v.create_nsg, true)
  }
 
  # 2) Convert rules list -> map keyed by rule name
  nsg_security_rules = {
    for nsg_key, nsg in local.nsg_create : nsg_key => {
      for r in try(nsg.security_rules, []) : r.name => {
        # required fields
        name      = r.name
        priority  = r.priority
        direction = r.direction
        access    = r.access
        protocol  = r.protocol
 
        # optional fields (pass only if present)
        source_address_prefix      = try(r.source_address_prefix, null)
        destination_address_prefix = try(r.destination_address_prefix, null)
 
        source_port_range      = try(r.source_port_range, null)
        destination_port_range = try(r.destination_port_range, null)
        source_address_prefixes      = try(r.source_address_prefixes, null)
        destination_address_prefixes = try(r.destination_address_prefixes, null)
        source_port_ranges           = try(r.source_port_ranges, null)
        destination_port_ranges      = try(r.destination_port_ranges, null)
 
        description = try(r.description, null)
      }
    }
  }
  # 5) Unified outputs (IDs of created + existing)
  nsg_ids = merge(
    { for k, m in module.nsg : k => m.resource_id },
    { for k, d in data.azurerm_network_security_group.existing : k => d.id }
  )
}
#--------------------------------------------------------------------
#Key Vault configurations
#--------------------------------------------------------------------
locals {
  keyvault_configs = {
    kv = {
      name                = "kv-cind-travel-test"
      location            = data.azurerm_resource_group.rg_paas.location
      resource_group_name = data.azurerm_resource_group.rg_paas.name
      sku_name           = "standard"
      soft_delete_retention_days      = 90
      purge_protection_enabled        = true
      legacy_access_policies_enabled  = false
      enabled_for_deployment          = true
      enabled_for_disk_encryption     = true
      enabled_for_template_deployment = true
      public_network_access_enabled   = false
      enable_telemetry                = false
      network_acls = {
        bypass         = "AzureServices"
        default_action = "Deny"
        virtual_network_subnet_refs = [
          {
            vnet_key   = "vnet_paas"
            subnet_key = "snet_paas"
          }
        ]
      }
      private_endpoints = {
        kvpe = {
          name       = "pvt-endpoint-kv-cind-travel-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        kvdiag = {
          name                  = "diag-settings"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_akv.id, null) # if you have LA workspace
        }
      }
      tags = {
        created_by = "terraform"
        INFY_EA_ResourceName = "kv-cind-travel-test"
        INFY_EA_CustomTag01 = "No Po"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMCFG"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_ProjectCode = "EPMPRJBE"
        INFY_EA_Automation = " Yes"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_Purpose = "IS_Internal"
        INFY_EA_Role = "key vault"
        INFY_EA_Technical_Tag = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_Workinghours = "00 = 00 23 =59"
        INFY_EA_WorkLoadType = "Test"
      }
    }
  }
}
 
#--------------------------------------------------------------------
# Function App configurations
#--------------------------------------------------------------------
locals {
  function_app_configs = {
    function1 = {
      name                                           = "func-travel-utility-test"
      location                                       = data.azurerm_resource_group.rg_paas.location
      resource_group_name                            = data.azurerm_resource_group.rg_paas.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          dotnet = {
            dotnet_version = "10.0"
            use_dotnet_isolated_runtime = true
             }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "dotnet-isolated"
        DOTNET_VERSION             = "10.0"
        # Add more app settings as needed
      }
      diagnostic_settings = {
        diag = {
          name                  = "diag-logs"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-utility-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
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
    function2 = {
      name                                           = "func-travel-ticketbookingreminder-test"
      location                                       = data.azurerm_resource_group.rg_paas.location
      resource_group_name                            = data.azurerm_resource_group.rg_paas.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          dotnet = {
            dotnet_version = "10.0"
            use_dotnet_isolated_runtime = true
            }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "dotnet-isolated"
        DOTNET_VERSION             = "10.0"
        # Add more app settings as needed
      }
      diagnostic_settings = {
        diag = {
          name                  = "diag-logs"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-ticketbookingreminder-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
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
        INFY_EA_ResourceName = "func-travel-ticketbookingreminder-test"
        INFY_EA_Role = "Function App"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_Workinghours = "NA"
        app_os = "linux"
      }
    }
    function3 = {
      name                                           = "func-travel-autoapproval-test"
      location                                       = data.azurerm_resource_group.rg_paas.location
      resource_group_name                            = data.azurerm_resource_group.rg_paas.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          dotnet = {
             dotnet_version = "10.0"
             use_dotnet_isolated_runtime = true
              }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "dotnet-isolated"
        DOTNET_VERSION             = "10.0"
        # Add more app settings as needed
      }
      diagnostic_settings = {
        diag = {
          name                  = "diag-logs"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-autoapproval-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
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
        INFY_EA_ResourceName = "func-travel-autoapproval-test"
        INFY_EA_Role = "Function App"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_Workinghours = "NA"
        app_os = "linux"
      }
    }
    function4 = {
      name                                           = "func-travel-eventmanagement-test"
      location                                       = data.azurerm_resource_group.rg_paas.location
      resource_group_name                            = data.azurerm_resource_group.rg_paas.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          dotnet = {
            dotnet_version = "10.0"
            use_dotnet_isolated_runtime = true
            }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "dotnet-isolated"
        DOTNET_VERSION             = "10.0"
        # Add more app settings as needed
      }
      diagnostic_settings = {
        diag = {
          name                  = "diag-logs"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-eventmanagement-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
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
        INFY_EA_ResourceName = "func-travel-eventmanagement-test"
        INFY_EA_Role = "Function App"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_Workinghours = "NA"
        app_os = "linux"
      }
    }
    function5 = {
      name                                           = "func-travel-uploadticket-test"
      location                                       = data.azurerm_resource_group.rg_paas.location
      resource_group_name                            = data.azurerm_resource_group.rg_paas.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
      storage_account_name                           = try(module.avm-res-storage-storageaccount["st_paas"].name, null)
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet_paas.snet_function"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          dotnet = {
            dotnet_version = "10.0"
            use_dotnet_isolated_runtime = true
            }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "dotnet-isolated"
        DOTNET_VERSION             = "10.0"
        # Add more app settings as needed
      }
      diagnostic_settings = {
        diag = {
          name                  = "diag-logs"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      private_endpoints = {
        functionpe = {
          name       = "pvt-endpoint-func-travel-uploadticket-test"
          vnet_key   = "vnet_paas"
          subnet_key = "snet_paas"
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
        INFY_EA_ResourceName = "func-travel-uploadticket-test"
        INFY_EA_Role = "Function App"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_WorkLoadType = "Test"
        INFY_EA_Workinghours = "NA"
        app_os = "linux"
      }
    }  
  }
}
#--------------------------------------------------------------------
# App Service Plan configurations
#--------------------------------------------------------------------
locals {
  app_service_plan = {
    plan1 = {
      name                = "asp-cind-travel-test"
      location            = data.azurerm_resource_group.rg_paas.location
      resource_group_name = data.azurerm_resource_group.rg_paas.name
      sku_name            = "P1v3"
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
      name                              = "stcindtraveltest"
      resource_group_name               = data.azurerm_resource_group.rg_paas.name
      location                          = data.azurerm_resource_group.rg_paas.location
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
          subnet_key = "snet_paas"
        }
      ]
      private_endpoints = {
        stpe = {
          name                          = "pvt-endpoint-stcindtraveltest"
          vnet_key                      = "vnet_paas"
          subnet_key                    = "snet_paas"
          subresource_name              = "blob"
          tags                          = { env = "test" }
        }
      }
      diagnostic_settings_blob = {
        stdiag = {
          name                  = "diag-settings-blob"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_storage_account.id, null)
          metric_categories     = ["Transaction", "Capacity"]
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
 
# API Management service configuration for API gateway and management
locals {
  apim_configs = {
    apim = {
      name                          = "apim-cind-travel-apps-test"
      location                      = data.azurerm_resource_group.rg_apim.location
      resource_group_name           = data.azurerm_resource_group.rg_apim.name
      publisher_name                = "Infosys"
      publisher_email               = var.travel_test_publisher_email
      sku_name                      = "Developer_1"
      virtual_network_type          = "Internal"
      virtual_network_subnet_id     = local.subnet_ids["vnet_apim.snet_apim"]
      diagnostic_settings = {
        diag1 = {
          name                  = "apim-diag"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law_function_app.id, null)
        }
      }
      tags = {
        created_by = "terraform"
        INFY_EA_Automation = "Yes"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_CustomTag01 = "No PO"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMProjects"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_ProjectCode = "EPMPRJBE"
        INFY_EA_Purpose = "IS Internal"
        INFY_EA_ResourceName = "apim-cind-travel-apps-test"
        INFY_EA_Role = "api Management"
        INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
        INFY_EA_WorkLoadType = "Test"
      }
    }
  }
}

variable "travel_test_publisher_email" {
  type = string
  default = ""
}