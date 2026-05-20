locals {
  virtual_networks = {
    vnet_aks = {
      create_vnet            = true
      parent_id              = data.azurerm_resource_group.rg_aks.id
      name                   = "vnet-sind-bcmsdr-mgmt"
      location               = data.azurerm_resource_group.rg_aks.location
      resource_group_name    = data.azurerm_resource_group.rg_aks.name
      address_space          = ["100.123.136.0/25"]
      dns_servers            = ["168.63.129.16"]     #["10.177.99.132"]
      ddos_protection_plan = {
        id = data.azurerm_ddos_protection_plan.ddos.id
        enabled = true
      }
      tags = {
        created_by = "terraform"
        INFY_BusinessUnit = "IS"
      }
      subnet_configs = {
        snet_aks = {
          name           = "snet-sind-node-mgmt"
          address_prefix = ["100.123.136.0/25"]
          #route_table   = { id = module.avm-res-network-routetable["rt_dr_aks"].resource_id }
        }
      }
    }
    vnet_pass = {
      create_vnet            = true
      parent_id              = data.azurerm_resource_group.rg_aks.id
      name                   = "vnet-sind-paas-dr-mgmt"
      location               = data.azurerm_resource_group.rg_aks.location
      resource_group_name    = data.azurerm_resource_group.rg_aks.name
      address_space          = ["100.123.136.128/25"]
      dns_servers            = ["10.177.99.132"]
      tags = {
        created_by = "terraform"
        INFY_BusinessUnit = "IS"
      }
      subnet_configs = {
        snet_pass = {
          name           = "snet-sind-paas-dr-mgmt"
          address_prefix = ["100.123.136.128/27"]
          service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
        }
        # snet_func = {
        #   name              = "snet-sind-func-dr-mgmt"
        #   address_prefix    = ["100.123.136.160/27"]
        #   service_endpoints = ["Microsoft.Web"]
        #   delegation = {
        #     name = "functionapp"
        #     service_delegation = {
        #       name    = "Microsoft.Web/serverFarms"
        #       actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        #     }
        #   }
        # }
      }
    }
    # vnet_sqlmi_dr = {
    #   create_vnet            = true
    #   parent_id             = data.azurerm_resource_group.rg_sqlmi_dr.id
    #   name                   = "vnet-sind-db-dr-mgmt"
    #   location               = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   resource_group_name    = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   address_space          = ["100.123.137.0/24"]
    #   dns_servers            = ["10.177.99.132"]
    #   tags = {
    #     created_by = "terraform"
    #   }
    #   subnet_configs = {
    #     snetmi_dr = {
    #       name           = "snet-sind-sqlmi-dr-mgmt"
    #       address_prefix = ["100.123.137.0/27"]
    #       nsg_key        = "nsg_sqlmi_dr"
    #       route_table   = { id = module.avm-res-network-routetable["rt_sqlmi_dr"].resource_id }
 
    #       delegation = {
    #         name = "managedinstancedelegation"
    #         service_delegation = {
    #           name    = "Microsoft.Sql/managedInstances"
    #           actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    #         }
    #       }
    #     }
    #     snet_pe = {
    #       name           = "snet-sind-sqlmi-pvt-dr-mgmt"
    #       address_prefix = ["100.123.137.32/27"]
    #       nsg_key        = "nsg_pe_dr"
    #       route_table   = { id = module.avm-res-network-routetable["rt_sqlmi_pe_dr"].resource_id }
    #     }
    #   }
    # }
  }
}
 
#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
    # nsg_sqlmi_dr = {
    #   create_nsg = true
    #   nsg_name   = "nsg-ManagedInstance-dr"
    #   location   = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   rg_name    = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   security_rules = [
    #     {
    #       direction                  = "Inbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-healthprobe-in-100-123-137-0-27-v11"
    #       source_address_prefix      = "AzureLoadBalancer"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.137.0/27"
    #       destination_port_range     = "*"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 100
    #     },
    #     {
    #       direction                  = "Inbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-internal-in-100-123-137-0-27-v11"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.137.0/27"
    #       destination_port_range     = "*"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 101
    #     },
    #     {
    #       direction                  = "Inbound"
    #       name                       = "prepare-allow_tds_inbound"
    #       source_address_prefix      = "VirtualNetwork"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.137.0/27"
    #       destination_port_ranges    = ["1433","11000-11999"]
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 1000
    #     },
    #     {
    #       direction                  = "Inbound"
    #       name                       = "prepare-deny_all_inbound"
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       protocol                   = "*"
    #       access                     = "Deny"
    #       priority                   = 4096
    #     },
    #     {
    #       direction                  = "Inbound"
    #       name                       = "allow_replication_Inbound_5022"
    #       source_address_prefix      = "100.122.1.32/27"  #put primary sqlmi vnet cidr
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.137.0/27"
    #       destination_port_range     = "5022"
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 1100
    #     },
    #     # Outbound rules
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-optional-azure-out-100-123-137-0-27"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "AzureCloud"
    #       destination_port_range     = "443"
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 100
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-aad-out-100-123-137-0-27-v11"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "AzureActiveDirectory"
    #       destination_port_range     = "443"
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 101
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-onedsc-out-100-123-137-0-27-v11"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "OneDsCollector"
    #       destination_port_range    = "443"
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 102
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-internal-out-100-123-137-0-27-v11 "
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.137.0/27"
    #       destination_port_range    = "*"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 103
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-strg-s-out-100-123-137-0-27-v11"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "Storage.centralindia"
    #       destination_port_range    = "443"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 109
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "Microsoft.Sql-managedInstances_UseOnly_mi-strg-p-out-100-123-137-0-27-v11"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "Storage.southindia"
    #       destination_port_range    = "443"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 108
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "AllowSQLMIstorage"
    #       source_address_prefix      = "100.123.137.0/27"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.136.128/27"
    #       destination_port_range    = "443"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 106
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "storage-access"
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.123.136.128/27"
    #       destination_port_range     = "443"
    #       protocol                   = "*"
    #       access                     = "Allow"
    #       priority                   = 107
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "prepare-deny_all_outbound"
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       protocol                   = "*"
    #       access                     = "Deny"
    #       priority                   = 4096
    #     },
    #     {
    #       direction                  = "Outbound"
    #       name                       = "allow_replication_Outbound_5022"
    #       source_address_prefix      = "100.123.137.0/27"  #put dr sqlmi vnet cidr
    #       source_port_range          = "*"
    #       destination_address_prefix = "100.122.1.32/27"  #put primary sqlmi vnet cidr
    #       destination_port_range     = "5022"
    #       protocol                   = "Tcp"
    #       access                     = "Allow"
    #       priority                   = 1000
    #     }
    #   ]
    #   tags = {
    #     created_by = "terraform"
    #   }
    # }
    # nsg_pe_dr = {
    #   create_nsg = true
    #   nsg_name   = "nsg-sind-iaas-default"
    #   location   = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   rg_name    = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   tags = {
    #     created_by = "terraform"
    #   }
    # }
  }
}
#--------------------------------------------------------------------
# Route Table configurations
#--------------------------------------------------------------------
locals {
  route_table_configs = {
    rt_dr_aks = {
      name = "rt-sinddr-vnet-sind-bcmsdr-mgmt"
      location = data.azurerm_resource_group.rg_aks.location
      resource_group_name = data.azurerm_resource_group.rg_aks.name
      bgp_route_propagation_enabled = false
    }
    # rt_sqlmi_dr = {
    #   name = "rt-sqlmi-vnet-sind-db-dr-mgmt"
    #   location = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   resource_group_name = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   bgp_route_propagation_enabled = false
    # }
    # rt_sqlmi_pe_dr = {
    #   name = "rt-sinddr-vnet-sind-db-dr-mgmt"
    #   location = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   resource_group_name = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   bgp_route_propagation_enabled = false
    # }
  }
}
 
#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    aks = {
      name                = "useridentity-isaksbcmsdrmgmt"
      location            = data.azurerm_resource_group.rg_aks.location
      resource_group_name = data.azurerm_resource_group.rg_aks.name
    }
    # function = {
    #   name                = "mannaged_identity_func-bcms_dr"
    #   location            = data.azurerm_resource_group.rg_pass.location
    #   resource_group_name = data.azurerm_resource_group.rg_pass.name
    # }
  }
}
 
 
# variable "sqlmi_admin_password" {
#   description = "Admin password for the DR SQL Managed Instance"
#   type        = string
#   sensitive   = true
#   validation {
#     condition  = length(var.sqlmi_admin_password) >= 16 && can(regex("[A-Z]", var.sqlmi_admin_password)) && can(regex("[a-z]", var.sqlmi_admin_password)) && can(regex("[0-9]", var.sqlmi_admin_password)) && can(regex("[^A-Za-z0-9]", var.sqlmi_admin_password))
#     error_message = "admin password must be at least 16 characters long and include at least one uppercase letter, one lowercase letter, one number, and one special character."
#   }
# }
# variable "sqlmi_administrator_login" {
#   description = "Admin username for the DR SQL Managed Instance"
#   type = string
# }
locals {
  sqlmi-configs-secondary = {
    # sqlmi_dr = {
    #   name                = "dbs-sind-mi-dr-mgmt"
    #   location            = data.azurerm_resource_group.rg_sqlmi_dr.location
    #   resource_group_name = data.azurerm_resource_group.rg_sqlmi_dr.name
    #   subnet_id = local.subnet_ids["vnet_sqlmi_dr.snetmi_dr"]  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
    #   administrator_login          = var.sqlmi_administrator_login
    #   administrator_login_password = var.sqlmi_admin_password
    #   sku_name                     = "GP_Gen5"
    #   vcores                       = 8
    #   storage_size_in_gb           = 800
    #   storage_account_type         = "LRS"
    #   license_type                 = "LicenseIncluded"
    #   timezone_id                  = "India Standard Time"
    #   proxy_override               = "Proxy"
    #   public_data_endpoint_enabled = false
    #   minimum_tls_version          = "1.2"
    #   zone_redundant_enabled       = false
    #   private_endpoints_manage_dns_zone_group = true
    #   dns_zone_partner_id = data.azurerm_mssql_managed_instance.sqlmi_primary.id
    #   private_endpoints = {
    #     sqlmipe = {
    #       name                          = "pvt-endpoint-dbs-sind-mi-dr-mgmt"
    #       vnet_key                      = "vnet_sqlmi_dr"
    #       subnet_key                    = "snet_pe"
    #       subresource_name              = "managedInstance"
    #     }
    #   }
    #   diagnostic_settings = {
    #     di_diag = {
    #       name                  = "diag-settings"
    #       workspace_resource_id = try(module.law.resource_id, null)
    #     }
    #   }
    #   tags = {
    #     created_by  = "terraform"
    #     INFY_EA_CustomTag01 = "No Po"
    #     INFY_EA_CustomTag02 = "Infosys Limited"
    #     INFY_EA_CustomTag03 = "EPMDBADMIN"
    #     INFY_EA_CustomTag04 = "PaaS"
    #     INFY_EA_ProjectCode = "EPMPRJBE"
    #     INFY_EA_Automation = " Yes"
    #     INFY_EA_BusinessUnit = "IS"
    #     INFY_EA_CostCenter = "No FR_IS"
    #     INFY_EA_Purpose = "IS_Internal"
    #     INFY_EA_ResourceName = "dbs-sind-mi-dr-mgmt"
    #     INFY_EA_Role = "SQL MI"
    #     INFY_EA_Technical_Tags = "EPMDBADMIN@infosys.com"
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_Workinghours = "00 = 00 23 =59"
    #     INFY_EA_WorkLoadType = "Mgmt"
    #   }
    # }
  }
}
 
 
#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
locals {
  aks_configs = {
    aks_dr = {
      name = "isaksbcmsdrmgmt0003"
      resource_group_name = data.azurerm_resource_group.rg_aks.name
      location = data.azurerm_resource_group.rg_aks.location
      node_resource_group_name   = "rg-sind-assets-isaksbcmsdrmgmt0001"
      kubernetes_version         = "1.33.5"
      sku_tier                   = "Standard"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = false
      http_application_routing_enabled = false
      node_os_channel_upgrade    = "None"
      dns_prefix = "isaksbcmsdrmgmt0002"
      local_account_disabled = false
      user_assigned_identity_keys                    = ["aks"]
      private_cluster_enabled    = true                    # force replacement of the cluster if changed
      role_based_access_control_enabled = false                      # force replacement of the cluster if changed
      # azure_active_directory_role_based_access_control = {
      #   tenant_id = data.azurerm_client_config.current.tenant_id
      #   admin_group_object_ids = try([data.azuread_group.ad_group.object_id], null)
      #   azure_rbac_enabled = false                         # (false uses Microsoft entra ID authentication with kubernetes RBAC)
      # }
      default_node_pool = {
        name            = "platform"
        vm_size         = "Standard_D4ds_v5"
        os_sku          = "AzureLinux3"     #AzureLinux
        os_disk_size_gb = 130
        os_disk_type    = "Managed"
       #zones           = ["1", "2", "3"]  #South india not supporting for availability zones
        min_count            = 1
        type                 = "VirtualMachineScaleSets"
        max_count            = 3
        auto_scaling_enabled = true
        max_pods             = 90
        vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
        node_taints          = ["CriticalAddonsOnly=true:NoSchedule"]
        node_labels = {
          "app" = "infysvc"
        }
      }
      # node_pools = {
      #   np1 = {
      #     name    = "usernp1"
      #     vm_size = "Standard_D4s_v5"
      #     mode    = "User"
      #     min_count            = 2
      #     max_count            = 10
      #     auto_scaling_enabled = true
      #     vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
      #     os_sku               = "AzureLinux3"
      #     os_type              = "Linux"
      #     os_disk_size_gb      = 128
      #     os_disk_type         = "Managed"
      #     max_pods             = 110
      #     node_labels = {
      #       "workload" = "apps"
      #     }
      #     node_taints          = ["node=infysvc:NoSchedule"]
      #     zones                = ["1", "2", "3"]
      #   }
      # }
      network_profile = {
        network_plugin      = "azure"
        network_policy      = "cilium"
        network_data_plane  = "cilium"  
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.0.0.10"
        service_cidr        = "10.0.0.0/16"
        pod_cidr            = "192.168.0.0/16"
        outbound_type     = "loadBalancer" #"userDefinedRouting"
        load_balancer_sku = "standard"
      }
      service_mesh_profile = {
        mode = "Istio"
        revisions = ["asm-1-28"]
        external_ingress_gateway_enabled = false
        internal_ingress_gateway_enabled = false
      }
      # diagnostic_settings = {
      #   di_diag = {
      #     name                  = "diag-aks-logs"
      #     storage_account_resource_id = data.azurerm_storage_account.dr_aks_diag.id
      #   }
      # }
      tags = {
        created_by  = "terraform"
        INFY_Appmaster_App_Name = "isaksbcmsdrmgmt"
        INFY_Appmaster_ID = "NA"
        INFY_BusinessUnit = "IS"
        INFY_CostCenter = "No FR_IS"
        INFY_Environment = "Mgmt"
        INFY_Managed_by = "IS"
        INFY_Owner = "EPM-Cloud@infosys.com"
        INFY_Platform = "Mgmt"
        INFY_ProjectCode = "EPMPRJBE"
        INFY_Provider = "Azure"
      }
 
    }
  }
}
 
#--------------------------------------------------------------------
# #Storage Account configurations
#--------------------------------------------------------------------
locals {
  storage_account_configs = {
    # st_pass_dr = {
    #   name                              = "stsindbcmsdrmgmt"
    #   resource_group_name               = data.azurerm_resource_group.rg_pass.name
    #   location                          = data.azurerm_resource_group.rg_pass.location
    #   account_tier                      = "Standard"
    #   account_replication_type          = "LRS"
    #   access_tier                       = "Hot"
    #   account_kind                      = "StorageV2"
    #   allow_nested_items_to_be_public   = false
    #   default_to_oauth_authentication   = true
    #   https_traffic_only_enabled        = true
    #   infrastructure_encryption_enabled = true
    #   local_user_enabled                = false
    #   min_tls_version                   = "TLS1_2"
    #   public_network_access_enabled     = false
    #   sftp_enabled                      = false
    #   shared_access_key_enabled         = true
    #   enable_telemetry                  = false
    #   blob_properties = {
    #     versioning_enabled            = false
    #     container_delete_retention_policy = {
    #       enabled = true
    #       days    = 7
    #     }
    #     delete_retention_policy = {
    #       days = 7
    #       permanent_delete_enabled = true
    #     }
    #   }
    #   network_rules_subnet_refs = [
    #     {
    #       vnet_key   = "vnet_pass"
    #       subnet_key = "snet_pass"
    #     }
    #   ]
    #   private_endpoints = {
    #     stpe = {
    #       name                          = "pvt-endpoint-stsindbcmsdrmgmt"
    #       vnet_key                      = "vnet_pass"
    #       subnet_key                    = "snet_pass"
    #       subresource_name              = "blob"
    #       tags                          = { env = "test" }
    #     }
    #   }
    #   diagnostic_settings_blob = {
    #     stdiag = {
    #       name                  = "diag-settings-blob"
    #       workspace_resource_id = try(module.law.resource_id, null)
    #       metric_categories     = ["Transaction", "Capacity"]
    #     }
    #   }
    #   tags = {
    #     created_by = "terraform"
    #     INFY_EA_ResourceName = "stsindbcmsdrmgmt"
    #     INFY_EA_CustomTag01 = "No PO"
    #     INFY_EA_CustomTag02 = "Infosys Limited"
    #     INFY_EA_CustomTag03 = "EPMDBADMIN"
    #     INFY_EA_CustomTag04 = "PaaS"
    #     INFY_EA_Automation = "No"
    #     INFY_EA_BusinessUnit = "IS"
    #     INFY_EA_CostCenter = "No FR_IS"
    #     INFY_EA_Purpose = "IS Internal"
    #     INFY_EA_Role = "Storage"
    #     INFY_EA_Technical_Tag = "EPMDBADMIN@infosys.com "
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_Workinghours  = "00 =00 23 =59"
    #     INFY_EA_WorkLoadType = "Mgmt"
    #     INFY_EA_ProjectCode = "EPMPRJBE"
    #   }
    # }
  }
}
 
#--------------------------------------------------------------------
#Key Vault configurations
#--------------------------------------------------------------------
locals {
  keyvault_configs = {
    # kv = {
    #   name                = "kv-sind-bcms-cmk-mgmt"
    #   location            = data.azurerm_resource_group.rg_aks.location
    #   resource_group_name = data.azurerm_resource_group.rg_aks.name
    #   sku_name           = "standard"
    #   soft_delete_retention_days      = 90
    #   purge_protection_enabled        = true
    #   legacy_access_policies_enabled  = false
    #   enabled_for_deployment          = true
    #   enabled_for_disk_encryption     = true
    #   enabled_for_template_deployment = true
    #   public_network_access_enabled   = false
    #   enable_telemetry                = false
    #   network_acls = {
    #     bypass         = "AzureServices"
    #     default_action = "Deny"
    #     virtual_network_subnet_refs = [
    #       {
    #         vnet_key   = "vnet_pass"
    #         subnet_key = "snet_pass"
    #       }
    #     ]
    #   }
    #   private_endpoints = {
    #     kvpe = {
    #       name       = "pvt-endpoint-kv-sind-bcms-dr-mgmt"
    #       vnet_key   = "vnet_pass"
    #       subnet_key = "snet_pass"
    #       private_dns_zone_resource_ids = []
    #     }
    #   }
    #   diagnostic_settings = {
    #     # kvdiag = {
    #     #   name                  = "diag-settings"
    #     #   workspace_resource_id = try(module.law.resource_id, null) # if you have LA workspace
    #     # }
    #   }
    #   tags = {
    #     created_by = "terraform"
    #     INFY_EA_ResourceName = "kv-sind-bcms-dr-mgmt"
    #     INFY_EA_CustomTag01 = "No Po"
    #     INFY_EA_CustomTag02 = "Infosys Limited"
    #     INFY_EA_CustomTag03 = "EPMCFG"
    #     INFY_EA_CustomTag04 = "PaaS"
    #     INFY_EA_ProjectCode = "EPMPRJBE"
    #     INFY_EA_Automation = " Yes"
    #     INFY_EA_BusinessUnit = "IS"
    #     INFY_EA_CostCenter = "No FR_IS"
    #     INFY_EA_Purpose = "IS_Internal"
    #     INFY_EA_Role = "key vault"
    #     INFY_EA_Technical_Tag = "EPM_CFG@infosys.com"
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_Workinghours = "00 = 00 23 =59"
    #     INFY_EA_WorkLoadType = "mgmt"
    #   }
    # }
  }
}
 
#--------------------------------------------------------------------
# Function App configurations
#--------------------------------------------------------------------
locals {
  function_app_configs = {
    # function1 = {
    #   name                                           = "func-bcms-dr-mgmt"
    #   location                                       = data.azurerm_resource_group.rg_pass.location
    #   resource_group_name                            = data.azurerm_resource_group.rg_pass.name
    #   kind                                           = "functionapp"
    #   os_type                                        = "Windows"
    #   https_only                                     = true
    #   service_plan_resource_id                       = try(module.avm-res-web-serverfarm["plan1"].resource_id, null)
    #   storage_account_name                           = try(module.avm-res-storage-storageaccount["st_pass_dr"].name, null)
    #   public_network_access_enabled                  = false
    #   enable_application_insights                    = false
    #   virtual_network_subnet_id                      = try(local.subnet_ids["vnet_pass.snet_func"], null)
    #   ftp_publish_basic_authentication_enabled       = false
    #   webdeploy_publish_basic_authentication_enabled = false
    #   user_assigned_identity_keys                    = ["function"]
    #   enable_telemetry                               = false
    #   site_config = {
    #     always_on        = false
    #     app_insights_key = "app_insights1"
    #     application_stack = {
    #       dotnet = { dotnet_version = "v8.0" }
    #     }
    #   }
    #   app_settings = {
    #     FUNCTIONS_WORKER_RUNTIME = "dotnet"
    #     DOTNET_VERSION             = "v8.0"
    #     # Add more app settings as needed
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
    #     INFY_EA_ResourceName = "func-bcms-dr-mgmt"
    #     INFY_EA_Role = "Function App"
    #     INFY_EA_Technical_Tags = "EPM_CFG@infosys.com"
    #     INFY_EA_Weekendshutdown = "No"
    #     INFY_EA_WorkLoadType = "Mgmt"
    #     INFY_EA_Workinghours = "NA"
    #     app_os = "windows"
    #   }
    # }
  }
}
#--------------------------------------------------------------------
# App Service Plan configurations
#--------------------------------------------------------------------
locals {
  app_service_plan = {
    # plan1 = {
    #   name                = "asp-sind-bcms-dr-mgmt"
    #   location            = data.azurerm_resource_group.rg_pass.location
    #   resource_group_name = data.azurerm_resource_group.rg_pass.name
    #   sku_name            = "P1v3"
    #   os_type             = "Windows"
    #   # maximum_elastic_worker_count = 20
    #   zone_balancing_enabled = false
    #   enable_telemetry    = false
    #   tags = {
    #     environment = "testing"
    #     created_by  = "terraform"
    #   }
    # }
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