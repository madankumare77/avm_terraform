data "azurerm_resource_group" "rg" {
  name = "rg-infosys-is"
}

locals {
  virtual_networks = {
    vnet1 = {
      create_vnet         = false
      name                = "vent-infy-is"
      resource_group_name = data.azurerm_resource_group.rg.name

      # list the subnets you want to reference from that existing vnet
      existing_subnets = {
        snetmi = { name = "subnet-mi" }
        snet1 = { name = "snet-pvt" }
        snet2 = { name = "snet-test" }
      }
    }
  }
}
#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
    nsg1 = {
      create_nsg = false
      nsg_name   = "mi-security-group"
      rg_name    = data.azurerm_resource_group.rg.name
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
        rg_name     = coalesce(try(vnet.resource_group_name, null), data.azurerm_resource_group.rg.name)
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

  # 2) Convert rules list -> map keyed by rule name (module requires map(object(...))) [1](https://github.com/Azure/terraform-azurerm-avm-res-network-networksecuritygroup)
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

        # If in future you use *ranges*, module supports these too [1](https://github.com/Azure/terraform-azurerm-avm-res-network-networksecuritygroup)
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
# User Assigned Identity
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    sqlmi = {
      name                = "mi-sqlmi-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }
  }
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
  parent_id = data.azurerm_resource_group.rg.id

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

locals {
  sqlmi-configs = {
    sqlmi_1 = {
      name                = "sql-mk-infy-01"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      subnet_id = local.subnet_ids["vnet1.snetmi"]  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
      administrator_login          = "sqladminuser"
      administrator_login_password = random_password.myadminpassword.result
      sku_name                     = "GP_Gen5"
      vcores                       = 4
      storage_size_in_gb           = 128
      license_type                 = "LicenseIncluded"
      timezone_id                  = "India Standard Time"
      proxy_override               = "Proxy"
      public_data_endpoint_enabled = false
      minimum_tls_version          = "1.2" #TLS 1.2 is the minimum supported version
      zone_redundant_enabled       = false
      user_assigned_identity_keys  = ["sqlmi"]
      # active_directory_administrator = {
      #   azuread_authentication_only = true
      #   object_id                   = data.azuread_group.sql_admins.object_id
      #   tenant_id                   = data.azurerm_client_config.current.tenant_id
      #   login_username              = "infy-test"
      # }
      private_endpoints_manage_dns_zone_group = false
      private_endpoints = {
        cosmospe = {
          name                          = "pvt-endpoint-sqlmi001"
          vnet_key                      = "vnet1"
          subnet_key                    = "snet1"
          subresource_name              = "MongoDB"
          #private_dns_zone_resource_ids = [local.private_dns_ids["cosmosdb"]]
        }
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-di-sqlmi-01"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
    }
  }
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
  location                     = data.azurerm_resource_group.rg.location
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
  enable_telemetry    = false

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



# resource "azuread_directory_role_member" "mi_uami_dirreaders" {
#   role_object_id   = azuread_directory_role.dir_readers.object_id
#   member_object_id = module.avm-res-managedidentity-userassignedidentity["sqlmi"].principal_id
# }


# resource "azuread_directory_role" "dir_readers" {
#   display_name = "Directory Readers"
# }
