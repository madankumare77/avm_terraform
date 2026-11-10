####Web app####
data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"
}

data "azurerm_application_insights" "appinsights" {
  name                = "app-insights-mk"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_log_analytics_workspace" "law" {
  name                = "IL-log-cind-test"
  resource_group_name = data.azurerm_resource_group.rg.name
}

module "vnet-webapp" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.16.0"
  name = "vnet-webapp"
  address_space          = ["10.1.0.0/16"]
  location = data.azurerm_resource_group.rg.location
  parent_id = data.azurerm_resource_group.rg.id
  enable_telemetry = false
  subnets = {
    "subnetpe" = {
      name             = "subnetpe"
      address_prefixes = ["10.1.0.0/24"]
    }
    "subnet2" = {
      name             = "subnet2"
      address_prefixes = ["10.1.1.0/24"]
      delegations = [
        {
          name = "delegation"
          service_delegation = {
            name    = "Microsoft.Web/serverfarms"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
          }
        }
      ]
    }
  }
}

#--------------------------------------------------------------------
# App Service Plan configurations
#--------------------------------------------------------------------
locals {
  app_service_plan = {
    plan1 = {
      name                = "asp-webapp-test"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
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
# AVM Web App module - pinned to 0.20.0
module "web_app" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.20.0"

  kind                     = "webapp"
  name                     = "webapp-test-mk"
  location                 = data.azurerm_resource_group.rg.location
  resource_group_name      = data.azurerm_resource_group.rg.name
  os_type                  = "Linux"
  service_plan_resource_id = module.avm-res-web-serverfarm["plan1"].resource_id
  enable_telemetry         = false
  https_only               = true
  enable_application_insights = false
  virtual_network_subnet_id = module.vnet-webapp.subnets["subnet2"].resource_id

  site_config = {
    always_on         = true
    ftps_state        = "Disabled"
    minimum_tls_version = "1.2"
    scm_minimum_tls_version = "1.2"
    http2_enabled     = true
    vnet_route_all_enabled = false 

    application_stack = {
      python = {
        python_version = "3.12"
      }
    }
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "1"
    APPINSIGHTS_INSTRUMENTATIONKEY = data.azurerm_application_insights.appinsights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = data.azurerm_application_insights.appinsights.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
  }

  managed_identities = {
    system_assigned = true
  }

  private_endpoints_manage_dns_zone_group = false
  private_endpoints = {
    webapppe = {
      name       = "pvt-endpoint-webapp-test"
      subnet_resource_id = module.vnet-webapp.subnets["subnetpe"].resource_id
    }
  }

  diagnostic_settings = {
    diag = {
      name                       = "webapp-test-diagnostics"
      workspace_resource_id      = data.azurerm_log_analytics_workspace.law.id
      log_groups = [ "allLogs", "audit" ]
    }
  }

  tags = {
    environment = "testing"
    created_by  = "terraform"
    }
}