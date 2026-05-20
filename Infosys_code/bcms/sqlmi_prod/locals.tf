locals {
  virtual_networks = {
    vnet_sqlmi = {
      create_vnet         = false
      name                = "vnet-cind-db-prod"
      resource_group_name = data.azurerm_resource_group.rg_sqlmi_vnet.name
 
      existing_subnets = {
        snet_sqlmi = { name = "snet-cind-sqlmi-bcms-prod" }
        snet_pe    = { name = "snet-cind-bcms-pvt-prod" }
      }
    }
  }
}
 
locals {
  sqlmi-configs-secondary = {
    sqlmi_bcms = {
      name                = "dbs-cind-bcms-prod"
      location            = data.azurerm_resource_group.rg_sqlmi.location
      resource_group_name = data.azurerm_resource_group.rg_sqlmi.name
      subnet_id = local.subnet_ids["vnet_sqlmi.snet_sqlmi"]  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
      administrator_login          = var.sqlmi_administrator_login
      administrator_login_password = var.sqlmi_admin_password
      sku_name                     = "GP_Gen8IM"
      vcores                       = 8
      storage_size_in_gb           = 1024
      storage_account_type         = "ZRS"
      license_type                 = "LicenseIncluded"
      timezone_id                  = "India Standard Time"
      proxy_override               = "Proxy"
      public_data_endpoint_enabled = false
      minimum_tls_version          = "1.2"
      zone_redundant_enabled       = true
      private_endpoints_manage_dns_zone_group = true
      managed_identities = {
        system_assigned = true
      }
      # active_directory_administrator = {
      #   azuread_authentication_only = true
      #   object_id                   = data.azuread_group.ad_group.object_id
      #   tenant_id                   = data.azurerm_client_config.current.tenant_id
      #   login_username              = data.azuread_group.ad_group.display_name
      # }
      private_endpoints = {
        sqlmipe = {
          name                          = "pvt-endpoint-dbs-cind-bcms-prod"
          vnet_key                      = "vnet_sqlmi"
          subnet_key                    = "snet_pe"
          subresource_name              = "managedInstance"
        }
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-settings"
          workspace_resource_id = try(data.azurerm_log_analytics_workspace.law.id, null)
        }
      }
      tags = {
        created_by  = "terraform"
        INFY_EA_CustomTag01 = "No Po"
        INFY_EA_CustomTag02 = "Infosys Limited"
        INFY_EA_CustomTag03 = "EPMDBADMIN"
        INFY_EA_CustomTag04 = "PaaS"
        INFY_EA_ProjectCode = "EPMPRJBE"
        INFY_EA_Automation = " Yes"
        INFY_EA_BusinessUnit = "IS"
        INFY_EA_CostCenter = "No FR_IS"
        INFY_EA_Purpose = "IS_Internal"
        INFY_EA_ResourceName = "dbs-cind-bcms-prod"
        INFY_EA_Role = "SQL MI"
        INFY_EA_Technical_Tags = "EPMDBADMIN@infosys.com"
        INFY_EA_Weekendshutdown = "No"
        INFY_EA_Workinghours = "00 = 00 23 =59"
        INFY_EA_WorkLoadType = "Prod"
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
 
 