data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"
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
      name                            = s.name
      address_prefixes                = s.address_prefix
      default_outbound_access_enabled = try(s.default_outbound_access_enabled, true)
      service_endpoints_with_location = [
        for svc in try(s.service_endpoints, []) : {
          service = svc
          # locations = [each.value.location] # use only if you want location restriction
        }
      ]

      #network_security_group = try((try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] }), null)
      route_table            = try(s.route_table, null)

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

module "postgresql" {
  source  = "Azure/avm-res-dbforpostgresql-flexibleserver/azurerm"
  version = "0.2.3"

  name     = "pgsql-with-version-test"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  administrator_login    = "pgsqlroot"
  administrator_password = var.postgresql_admin_password
  server_version = "18"
  sku_name   = "GP_Standard_D8ds_v5"
  storage_mb = 131072
  #delegated_subnet_id = local.subnet_ids["vnet-primary.snetpsql"]
  public_network_access_enabled = false
  zone = "3"
  backup_retention_days = 7
  high_availability = {
    mode = "ZoneRedundant"
  }
  authentication = {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }
  diagnostic_settings = {
    di_diag = {
      name                  = "diag-settings"
      workspace_resource_id = try(module.law.resource_id, null)
    }
  }
  private_endpoints_manage_dns_zone_group = false
  private_endpoints = {
    pgsqlpe = {
      name                          = "pvt-endpoint-pgsql-with-version-test"
      subresource_name              = "postgresqlServer"
      subnet_resource_id            = local.subnet_ids["vnet-primary.snetpe"]
    }
  }
  tags = {
    Environment = "test"
    Workload    = "PaaS"
  }
  enable_telemetry = false
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

variable "postgresql_admin_password" {
  description = "Admin password for the DR PostgreSQL Flexible Server"
  type        = string
  sensitive   = true
  default = "Cricket@11$11$55$22"
  validation {
    condition  = length(var.postgresql_admin_password) >= 16 && can(regex("[A-Z]", var.postgresql_admin_password)) && can(regex("[a-z]", var.postgresql_admin_password)) && can(regex("[0-9]", var.postgresql_admin_password)) && can(regex("[^A-Za-z0-9]", var.postgresql_admin_password))
    error_message = "admin password must be at least 16 characters long and include at least one uppercase letter, one lowercase letter, one number, and one special character."
  }
}
# variable "postgresql_administrator_login" {
#   description = "Admin username for the DR PostgreSQL Flexible Server"
#   type = string
# }


# resource "azurerm_private_endpoint" "pe" {
#   name                = "postgresql-pe"
#   location                                  = data.azurerm_resource_group.rg.location
#   resource_group_name                       = data.azurerm_resource_group.rg.name
#   subnet_id           = local.subnet_ids["vnet-primary.snetpe"]

#   private_service_connection {
#     name                           = "postgresql-psc"
#     private_connection_resource_id = module.postgresql.resource_id
#     is_manual_connection           = false
#     subresource_names              = ["postgresqlServer"]
#   }

#   lifecycle {
#     ignore_changes = all
#   }
# }



resource "azurerm_private_dns_zone" "example" {
  name                = "postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = local.vnet_ids["vnet-primary"]
  resource_group_name   = data.azurerm_resource_group.rg.name
}