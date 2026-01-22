data "azurerm_resource_group" "rg" {
  name = "rg-infosys-is"
}

data "azurerm_resource_group" "rg_dr" {
  name = "rg-infosys-is-dr"
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
  parent_id = try(each.value.parent_id, data.azurerm_resource_group.rg.id)

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

      network_security_group = try((try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] }), null)
      route_table = try(s.route_table, null)

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
  resource_group_name = coalesce(try(each.value.resource_group_name, null), data.azurerm_resource_group.rg.name)
}
data "azurerm_subnet" "existing" {
  for_each             = { for k, v in local.existing_subnets_flat : k => v }
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
  for_each            = { for k, v in local.nsg_create : k => v }
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
  for_each            = { for k, v in local.nsg_lookup : k => v }
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
}


module "avm-res-network-routetable" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.4.1"
  name = "sqlmi-route-table-dr"
  #location = data.azurerm_resource_group.rg_dr.location
  location = "japaneast"
  resource_group_name = data.azurerm_resource_group.rg_dr.name
  enable_telemetry    = false
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



###############################################################


resource "random_password" "myadminpassword" {
  length           = 16
  override_special = "@#%*()-_=+[]{}:?"
  special          = true
}



data "azuread_group" "sql_admins" {
  display_name   = "infy-test"
  security_enabled = true
}


#This is the module call
module "sqlmi_test" {
  source = "Azure/avm-res-sql-managedinstance/azurerm"
  version = "0.1.3"
  for_each = { for k, v in local.sqlmi-configs : k => v }

  name                         = each.value.name
  location                     = each.value.location
  administrator_login          = each.value.administrator_login
  administrator_login_password = random_password.myadminpassword.result
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
  storage_account_type = "GRS"
  enable_telemetry    = false
  dns_zone_partner_id = try(each.value.dns_zone_partner_id, null)

  managed_identities = {
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }

  # active_directory_administrator = {
  #   azuread_authentication_only = each.value.active_directory_administrator.azuread_authentication_only
  #   object_id = each.value.active_directory_administrator.object_id
  #   tenant_id = each.value.active_directory_administrator.tenant_id
  #   login_username = each.value.active_directory_administrator.login_username
  # }

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
      }
    }
    : null
  )

  depends_on = [
    module.avm-res-managedidentity-userassignedidentity, module.nsg
  ]
}

module "sqlmi_secondary" {
  source = "Azure/avm-res-sql-managedinstance/azurerm"
  version = "0.1.3"
  for_each = { for k, v in local.sqlmi-configs-secondary : k => v }

  name                         = each.value.name
  location                     = each.value.location
  administrator_login          = each.value.administrator_login
  administrator_login_password = random_password.myadminpassword.result
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
  storage_account_type = "GRS"
  enable_telemetry    = false
  dns_zone_partner_id = try(each.value.dns_zone_partner_id, null)

  managed_identities = {
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }

  # active_directory_administrator = {
  #   azuread_authentication_only = each.value.active_directory_administrator.azuread_authentication_only
  #   object_id = each.value.active_directory_administrator.object_id
  #   tenant_id = each.value.active_directory_administrator.tenant_id
  #   login_username = each.value.active_directory_administrator.login_username
  # }

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
      }
    }
    : null
  )

  depends_on = [
    module.avm-res-managedidentity-userassignedidentity, module.nsg, module.sqlmi_test, module.avm_res_network_virtualnetwork
  ]
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

variable "enable_log_analytics_workspace" {
  type = bool
  default = true
}




#Peering primary <-> DR VNets
resource "azurerm_virtual_network_peering" "primary_to_dr" {
  name                      = "peer-primary-to-dr"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = data.azurerm_virtual_network.existing["vnet1"].name
  remote_virtual_network_id = module.avm_res_network_virtualnetwork["vnet-dr"].resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  depends_on = [module.avm_res_network_virtualnetwork]
}

resource "azurerm_virtual_network_peering" "dr_to_primary" {
  name                      = "peer-dr-to-primary"
  resource_group_name       = data.azurerm_resource_group.rg_dr.name
  virtual_network_name      = module.avm_res_network_virtualnetwork["vnet-dr"].name
  remote_virtual_network_id = data.azurerm_virtual_network.existing["vnet1"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

