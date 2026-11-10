data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"
}

locals {
  virtual_networks = {
    vnet_primary = {
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
          #nsg_key        = "nsg_primary"
        }
      }
    }
  }
}

#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
module "vnet" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.16.0"
  for_each = { for k, v in local.virtual_networks : k => v }

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


module "redis" {
  source  = "Azure/avm-res-cache-redisenterprise/azurerm"
  version = "~> 0.1"

  location            = "${data.azurerm_resource_group.rg.location}"
  name                = "myredismk"
  parent_id           = data.azurerm_resource_group.rg.id

  sku_name            = "Balanced_B3"
  minimum_tls_version = "1.2"
  enable_non_ssl_port = false
  clustering_policy   = "EnterpriseCluster"
  eviction_policy     = "AllKeysLRU"
  enable_telemetry    = false

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = []
  }

  access_policy_assignments = {
    app_identity = {
      object_id          = module.avm-res-managedidentity-userassignedidentity["aks"].principal_id
      access_policy_name = "default"
    }
  }

  private_endpoints = {
    pe1 = {
        name                                    = "pe-redis"
        subnet_resource_id                      = module.vnet["vnet_primary"].subnets["snet_pe"].resource_id
    }
  }
}

locals {
  user_assigned_identities = {
    aks = {
      name                = "mi-aks-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }
  }
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

resource "azurerm_monitor_diagnostic_setting" "redis_diag" {
  name                       = "redis-diagnostics"
  target_resource_id         = module.redis.resource_id
  log_analytics_workspace_id = try(module.law.resource_id, null)

  enabled_metric  {
    category = "AllMetrics"
  }
}