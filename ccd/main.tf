data "azurerm_client_config" "current" {} 

locals {
  # Power Platform region to Azure region pair mapping
  # Source: https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview#supported-regions
  power_platform_region_map = {
    "United States"  = ["eastus", "westus"]
    "South Africa"   = ["southafricanorth", "southafricawest"]
    "UK"             = ["uksouth", "ukwest"]
    "Japan"          = ["japaneast", "japanwest"]
    "India"          = ["centralindia", "southindia"]
    "France"         = ["francecentral", "francesouth"]
    "Europe"         = ["westeurope", "northeurope"]
    "Germany"        = ["germanynorth", "germanywestcentral"]
    "Switzerland"    = ["switzerlandnorth", "switzerlandwest"]
    "Canada"         = ["canadacentral", "canadaeast"]
    "Brazil"         = ["brazilsouth"]
    "Australia"      = ["australiasoutheast", "australiaeast"]
    "Asia"           = ["eastasia", "southeastasia"]
    "UAE"            = ["uaenorth"]
    "Korea"          = ["koreasouth", "koreacentral"]
    "Norway"         = ["norwaywest", "norwayeast"]
    "Singapore"      = ["southeastasia"]
    "Sweden"         = ["swedencentral"]
    "Italy"          = ["italynorth"]
    "US Government"  = ["usgovtexas", "usgovvirginia"]
  }

  pp_azure_regions    = local.power_platform_region_map[var.power_platform_region]
  # The primary region is where the main VNet lives (resource_group_location)
  # The secondary/paired region is the other region from the PP pair
  pp_secondary_regions = [for r in local.pp_azure_regions : r if r != var.resource_group_location]
  pp_secondary_region  = length(local.pp_secondary_regions) > 0 ? local.pp_secondary_regions[0] : null
}

############## resource group CCD corp tenant##############

module "avm-res-resources-resourcegroup" {
  # This module creates an Azure Resource Group
  # Source: https://registry.terraform.io/modules/Azure/avm-res-resources-resourcegroup/azurerm/latest
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.2"

  # Resource Group Configuration
  name     = var.resource_group_name
  location = var.resource_group_location
  enable_telemetry = false
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
}

################APIM NSG CCD corp tenant ##############

module "avm-res-network-networksecuritygroup_apim" {
  # This module creates an Azure Network Security Group
  # Source: https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/latest
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  # Network Security Group Configuration
  name                = var.nsg_apim_name
  location            = var.resource_group_location
  resource_group_name = module.avm-res-resources-resourcegroup.name
  enable_telemetry    = false

  security_rules = {
    Allow-Client-HTTP-HTTPS = {
      name                       = "Allow-Client-HTTP-HTTPS"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["80", "443"]
      source_address_prefix      = "Internet"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-APIM-Management-3443 = {
      name                       = "Allow-APIM-Management-3443"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3443"
      source_address_prefix      = "ApiManagement"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-AzureLoadBalancer-6390 = {
      name                       = "Allow-AzureLoadBalancer-6390"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6390"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-TrafficManager-443 = {
      name                       = "Allow-TrafficManager-443"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "AzureTrafficManager"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-AzureLoadBalancer-6391 = {
      name                       = "Allow-AzureLoadBalancer-6391"
      priority                   = 140
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6391"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-Out-Cert-Validation = {
      name                       = "Allow-Out-Cert-Validation"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "Internet"
    }
  
    Allow-Out-Storage-443 = {
      name                       = "Allow-Out-Storage-443"
      priority                   = 210
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "Storage"
    }
  
    Allow-Out-AzureAD-443 = {
      name                       = "Allow-Out-AzureAD-443"
      priority                   = 220
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "AzureActiveDirectory"
    }
  
    Allow-Out-AzureConnectors-443 = {
      name                       = "Allow-Out-AzureConnectors-443"
      priority                   = 230
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "AzureConnectors"
    }
  
    Allow-Out-SQL-1433 = {
      name                       = "Allow-Out-SQL-1433"
      priority                   = 240
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "Sql"
    }
  
    Allow-Out-KeyVault-443 = {
      name                       = "Allow-Out-KeyVault-443"
      priority                   = 250
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "AzureKeyVault"
    }
  
    Allow-Out-EventHub = {
      name                       = "Allow-Out-EventHub"
      priority                   = 260
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443", "5671", "5672"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "EventHub"
    }
  
    Allow-Out-AzureMonitor = {
      name                       = "Allow-Out-AzureMonitor"
      priority                   = 270
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443", "1886"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "AzureMonitor"
    }
  
    Allow-Redis-6380 = {
      name                       = "Allow-Redis-6380"
      priority                   = 300
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6380"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-Redis-Internal = {
      name                       = "Allow-Redis-Internal"
      priority                   = 310
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["6381", "6382", "6383"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  
    Allow-RateLimit-Sync = {
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
    }

  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
  
  depends_on = [module.avm-res-resources-resourcegroup]
}



################ Virtual Network CCD corp tenant ##############

# AVM Module for Azure Virtual Network
module "avm-res-network-virtualnetwork" {
  # This module creates an Azure Virtual Network
  # Source: https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/latest
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  # Virtual Network Configuration
  name                = var.virtual_network_name
  address_space       = [var.vnet_address_space]
  location            = var.resource_group_location
  parent_id           = module.avm-res-resources-resourcegroup.resource_id
  enable_telemetry    = false

  subnets = {
    subnet1 = {
      name           = "AzureFirewallSubnet"
      address_prefix = var.firewall_subnet_address_prefix
      service_endpoints_with_location = []
    }
    subnet2 = {
      name           = var.apim_subnet_name
      address_prefix = var.apim_subnet_address_prefix
      # delegations = [{
      #   name = "Microsoft.Web.serverFarms"
      #   service_delegation = {
      #     name = "Microsoft.Web/serverFarms"
      #   }
      # }]
      service_endpoints_with_location = [
        {
          service  = "Microsoft.Storage"
        },
        {
          service  = "Microsoft.Sql"
        },
        {
          service  = "Microsoft.KeyVault"
        },
        {
          service  = "Microsoft.EventHub"
        },
        {
          service  = "Microsoft.AzureActiveDirectory"
        }
      ]
      network_security_group = {
        id = module.avm-res-network-networksecuritygroup_apim.resource_id
      }
      route_table = {
        id = azurerm_route_table.apim.id
      }

    }
    subnet3 = {
      name           = var.private_endpoint_subnet_name
      address_prefix = var.private_endpoint_subnet_address_prefix
      service_endpoints_with_location = []
      network_security_group = {
        id = module.nsg_default.resource_id
      }
      route_table = {
        id = azurerm_route_table.apim.id
      }
    }
    subnet4 = {
      name           = var.pp_subnet_name
      address_prefix = var.pp_subnet_address_prefix
      service_endpoints_with_location = []
      delegations = [{
        name = "Microsoft.PowerPlatform.enterprisePolicies"
        service_delegation = {
          name = "Microsoft.PowerPlatform/enterprisePolicies"
        }
      }]
      network_security_group = {
        id = module.nsg_default.resource_id
      }
      route_table = {
        id = azurerm_route_table.apim.id
      }
    }
  }
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
    depends_on = [module.avm-res-resources-resourcegroup, module.avm-res-network-networksecuritygroup_apim, azurerm_route_table.apim]
}


######### key vault CCD corp tenant ##############


resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = module.avm-res-resources-resourcegroup.name

  depends_on = [module.avm-res-resources-resourcegroup]
}   

module "avm-res-keyvault-vault" {
    source  = "Azure/avm-res-keyvault-vault/azurerm"
    version = "0.10.2"

    location           = var.resource_group_location
    name              = var.key_vault_name
    resource_group_name = module.avm-res-resources-resourcegroup.name   
    tenant_id         = data.azurerm_client_config.current.tenant_id
    enable_telemetry  = false
    private_endpoints = {
        primary = {
        private_dns_zone_resource_ids = [azurerm_private_dns_zone.this.id]
        subnet_resource_id            = module.avm-res-network-virtualnetwork.subnets["subnet3"].resource_id
        }
    }
    public_network_access_enabled = false
    tags = {
      created_by = "terraform"
      Environment = "CCD-test"
    }

    diagnostic_settings = {
      kv_diag = {
        name               = "kv-diagnostic"
        workspace_resource_id = module.law.resource_id
      }
    }

    depends_on = [module.avm-res-resources-resourcegroup, module.avm-res-network-virtualnetwork]
}


################ Azure Firewall and firewall policy CCD corp tenant ##############

resource "azurerm_public_ip" "firewall" {
  name                = var.firewall_public_ip_name
  location            = var.resource_group_location
  resource_group_name = module.avm-res-resources-resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  ip_tags = {
    FirstPartyUsage = "/Unprivileged"
  }
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }

  depends_on = [module.avm-res-resources-resourcegroup]
}
resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "${var.firewall_public_ip_name}-diag"
  target_resource_id             = azurerm_public_ip.firewall.id
  log_analytics_destination_type = "Dedicated"
  log_analytics_workspace_id     = module.law.resource_id
  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}



module "avm-res-network-firewallpolicy" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm"
  version = "0.3.4"

  location            = var.resource_group_location
  name                = var.firewall_policy_name
  resource_group_name = module.avm-res-resources-resourcegroup.name
  enable_telemetry    = false
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
}


module "avm-res-network-azurefirewall" {
  source  = "Azure/avm-res-network-azurefirewall/azurerm"
  version = "0.4.0"

  firewall_sku_name    = "AZFW_VNet"
  firewall_sku_tier    = "Standard"
  location             = var.resource_group_location
  name                 = var.firewall_name
  resource_group_name  = module.avm-res-resources-resourcegroup.name
  enable_telemetry     = false
  firewall_policy_id   = module.avm-res-network-firewallpolicy.resource_id
  firewall_zones       = ["1", "2", "3"]
  ip_configurations = {
    default = {
      name                 = "ipconfig1"
      subnet_id            = module.avm-res-network-virtualnetwork.subnets["subnet1"].resource_id
      public_ip_address_id = azurerm_public_ip.firewall.id
    }
  }
  diagnostic_settings = {
    fw_diag = {
      name               = "fw-diagnostic"
      workspace_resource_id = module.law.resource_id
    }
  }
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }

    depends_on = [module.avm-res-resources-resourcegroup, module.avm-res-network-virtualnetwork, module.avm-res-network-firewallpolicy]
}


################ Firewall Rules ##############

resource "azurerm_firewall_policy_rule_collection_group" "default" {
  name               = "default-rule-collection-group"
  firewall_policy_id = module.avm-res-network-firewallpolicy.resource_id
  priority           = 100

  network_rule_collection {
    name     = "network-rules"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "apim-to-pp-subnet"
      protocols             = ["Any"]
      source_addresses      = [var.apim_subnet_address_prefix]
      destination_addresses = [var.pp_subnet_address_prefix]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "pp-subnet-to-pe-subnet"
      protocols             = ["Any"]
      source_addresses      = [var.pp_subnet_address_prefix]
      destination_addresses = [var.private_endpoint_subnet_address_prefix]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "apim-to-pe-subnet"
      protocols             = ["Any"]
      source_addresses      = [var.apim_subnet_address_prefix]
      destination_addresses = [var.private_endpoint_subnet_address_prefix]
      destination_ports     = ["443"]
    }
  }

  application_rule_collection {
    name     = "application-rules"
    priority = 300
    action   = "Allow"

    rule {
      name = "allow-http-https"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["infosysapps.com"]
    }
  }

  depends_on = [module.avm-res-network-firewallpolicy, module.avm-res-network-azurefirewall]
}


############ APIM CCD corp tenant ##############

# resource "azurerm_private_dns_zone" "apim" {
#   name                = "privatelink.azure-api.net"
#   resource_group_name = module.avm-res-resources-resourcegroup.name

#   depends_on = [module.avm-res-resources-resourcegroup]
# }

module "avm-res-apimanagement-service" {
  source  = "Azure/avm-res-apimanagement-service/azurerm"
  version = "0.0.7"
  location            = var.resource_group_location
  name                = var.apim_name
  publisher_email     = "v-maeligeti@microsoft.com"
  resource_group_name = module.avm-res-resources-resourcegroup.name
  enable_telemetry    = false
  managed_identities = {
    system_assigned = true
  }
  publisher_name                = "Infosys"
  sku_name                      = var.apim_sku_name
  virtual_network_type          = "Internal"  #"External"
  virtual_network_subnet_id     = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id

  # private_endpoints = {
  #   endpoint1 = {
  #     name               = "pe-${var.apim_name}"
  #     subnet_resource_id = module.avm-res-network-virtualnetwork.subnets["subnet3"].resource_id

  #     # Link to the private DNS zone we created
  #     private_dns_zone_resource_ids = [
  #       azurerm_private_dns_zone.apim.id
  #     ]
  #   }
  # }

  diagnostic_settings = {
    apim_diag = {
      name               = "apim-diagnostic"
      workspace_resource_id = module.law.resource_id
    }
  }

  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }

  depends_on = [
    module.avm-res-resources-resourcegroup,
    module.avm-res-network-virtualnetwork,
    #azurerm_private_dns_zone.apim
  ]
}

####disable apim public access (post-creation) ##########

# resource "azapi_update_resource" "disable_apim_public_access" {
#   type        = "Microsoft.ApiManagement/service@2024-05-01"
#   resource_id = module.avm-res-apimanagement-service.resource_id

#   body = {
#     properties = {
#       publicNetworkAccess = "Disabled"
#     }
#   }

#   lifecycle {
#     ignore_changes = [body]
#   }

#   depends_on = [module.avm-res-apimanagement-service]
# }


################ Private DNS Zones (Blob & File) ##############

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = module.avm-res-resources-resourcegroup.name

  depends_on = [module.avm-res-resources-resourcegroup]
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = module.avm-res-resources-resourcegroup.name

  depends_on = [module.avm-res-resources-resourcegroup]
}


################ Private DNS Zone Virtual Network Links ##############

# Key Vault DNS - Primary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_primary" {
  name                  = "link-keyvault-primary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.this, module.avm-res-network-virtualnetwork]
}

# Key Vault DNS - Secondary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_secondary" {
  count = local.pp_secondary_region != null ? 1 : 0

  name                  = "link-keyvault-secondary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = module.pp_secondary_vnet[0].resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.this, module.pp_secondary_vnet]
}

# APIM DNS - Primary VNet
# resource "azurerm_private_dns_zone_virtual_network_link" "apim_primary" {
#   name                  = "link-apim-primary"
#   resource_group_name   = module.avm-res-resources-resourcegroup.name
#   private_dns_zone_name = azurerm_private_dns_zone.apim.name
#   virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
#   registration_enabled  = false

#   depends_on = [azurerm_private_dns_zone.apim, module.avm-res-network-virtualnetwork]
# }

# APIM DNS - Secondary VNet
# resource "azurerm_private_dns_zone_virtual_network_link" "apim_secondary" {
#   count = local.pp_secondary_region != null ? 1 : 0

#   name                  = "link-apim-secondary"
#   resource_group_name   = module.avm-res-resources-resourcegroup.name
#   private_dns_zone_name = azurerm_private_dns_zone.apim.name
#   virtual_network_id    = module.pp_secondary_vnet[0].resource_id
#   registration_enabled  = false

#   depends_on = [azurerm_private_dns_zone.apim, module.pp_secondary_vnet]
# }

# Blob DNS - Primary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob_primary" {
  name                  = "link-blob-primary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.blob, module.avm-res-network-virtualnetwork]
}

# Blob DNS - Secondary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob_secondary" {
  count = local.pp_secondary_region != null ? 1 : 0

  name                  = "link-blob-secondary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = module.pp_secondary_vnet[0].resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.blob, module.pp_secondary_vnet]
}

# File DNS - Primary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "file_primary" {
  name                  = "link-file-primary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.file, module.avm-res-network-virtualnetwork]
}

# File DNS - Secondary VNet
resource "azurerm_private_dns_zone_virtual_network_link" "file_secondary" {
  count = local.pp_secondary_region != null ? 1 : 0

  name                  = "link-file-secondary"
  resource_group_name   = module.avm-res-resources-resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = module.pp_secondary_vnet[0].resource_id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.file, module.pp_secondary_vnet]
}


################ Power Platform Secondary VNet (paired region) ##############

module "pp_secondary_vnet" {
  count = local.pp_secondary_region != null ? 1 : 0

  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  name                = "${var.pp_secondary_vnet_name}-${local.pp_secondary_region}"
  address_space       = [var.pp_secondary_vnet_address_space]
  location            = local.pp_secondary_region
  parent_id           = module.avm-res-resources-resourcegroup.resource_id
  enable_telemetry    = false

  subnets = {
    pp_subnet = {
      name           = "${var.pp_subnet_name}-${local.pp_secondary_region}"
      address_prefix = var.pp_secondary_subnet_address_prefix
      service_endpoints_with_location = []
      delegations = [{
        name = "Microsoft.PowerPlatform.enterprisePolicies"
        service_delegation = {
          name = "Microsoft.PowerPlatform/enterprisePolicies"
        }
      }]
      network_security_group = {
        id = module.nsg_pp_secondary.resource_id
      }
      route_table = {
        id = azurerm_route_table.pp_secondary.id
      }
    }
  }
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
  depends_on = [module.avm-res-resources-resourcegroup]
}


################ VNet Peering (optional) ##############

module "vnet_peering_primary_to_secondary" {
  count = var.enable_vnet_peering && local.pp_secondary_region != null ? 1 : 0

  source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version = "0.17.1"

  name                         = "peer-primary-to-${local.pp_secondary_region}"
  parent_id                    = module.avm-res-network-virtualnetwork.resource_id
  remote_virtual_network_id    = module.pp_secondary_vnet[0].resource_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  create_reverse_peering               = true
  reverse_name                         = "peer-${local.pp_secondary_region}-to-primary"
  reverse_allow_forwarded_traffic      = true
  reverse_allow_virtual_network_access = true
  reverse_allow_gateway_transit        = false
  reverse_use_remote_gateways          = false

  depends_on = [module.avm-res-network-virtualnetwork, module.pp_secondary_vnet]
}


################ Power Platform Enterprise Policy (ARM Template) ##############

resource "azurerm_resource_group_template_deployment" "pp_enterprise_policy" {
  name                = "${var.pp_enterprise_policy_name}-deployment"
  resource_group_name = module.avm-res-resources-resourcegroup.name
  deployment_mode     = "Incremental"

  parameters_content = jsonencode({
    policyName = {
      value = var.pp_enterprise_policy_name
    }
    powerplatformEnvironmentRegion = {
      value = lower(var.power_platform_region)
    }
    vNetOneSubnetName = {
      value = var.pp_subnet_name
    }
    vNetOneResourceId = {
      value = module.avm-res-network-virtualnetwork.resource_id
    }
    vNetTwoSubnetName = {
      value = local.pp_secondary_region != null ? "${var.pp_subnet_name}-${local.pp_secondary_region}" : ""
    }
    vNetTwoResourceId = {
      value = local.pp_secondary_region != null ? module.pp_secondary_vnet[0].resource_id : ""
    }
  })

  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "policyName": {
            "type": "String",
            "metadata": {
                "description": "The name of the Enterprise Policy."
            }
        },
        "powerplatformEnvironmentRegion": {
            "type": "String",
            "metadata": {
                "description": "Geography of the PowerPlatform environment."
            }
        },
        "vNetOneSubnetName": {
            "type": "String"
        },
        "vNetOneResourceId": {
            "type": "String",
            "metadata": {
                "description": "Fully qualified name, such as /subscription/{subscriptionid}/..."
            }
        },
        "vNetTwoSubnetName": {
            "defaultValue": "",
            "type": "String"
        },
        "vNetTwoResourceId": {
            "defaultValue": "",
            "type": "String",
            "metadata": {
                "description": "Fully qualified name, such as /subscription/{subscriptionid}/..."
            }
        }
    },
    "variables": {
        "vNetOne": {
            "id": "[parameters('vNetOneResourceId')]",
            "subnet": {
                "name": "[parameters('vNetOneSubnetName')]"
            }
        },
        "vNetTwo": {
            "id": "[parameters('vNetTwoResourceId')]",
            "subnet": {
                "name": "[parameters('vNetTwoSubnetName')]"
            }
        },
        "vNetTwoSupplied": "[and(not(empty(parameters('vNetTwoSubnetName'))), not(empty(parameters('vNetTwoResourceId'))))]"
    },
    "resources": [
        {
            "type": "Microsoft.PowerPlatform/enterprisePolicies",
            "apiVersion": "2020-10-30-preview",
            "name": "[parameters('policyName')]",
            "location": "[parameters('powerplatformEnvironmentRegion')]",
            "kind": "NetworkInjection",
            "properties": {
                "networkInjection": {
                    "virtualNetworks": "[if(variables('vNetTwoSupplied'), concat(array(variables('vNetOne')), array(variables('vNetTwo'))), array(variables('vNetOne')))]"
                }
            }
        }
    ]
}
TEMPLATE

  depends_on = [
    module.avm-res-resources-resourcegroup,
    module.avm-res-network-virtualnetwork,
    module.pp_secondary_vnet
  ]
}


################# route table ##################

resource "azurerm_route_table" "apim" {
  name                = var.route_table_name
  location            = var.resource_group_location
  resource_group_name = module.avm-res-resources-resourcegroup.name

  depends_on = [module.avm-res-resources-resourcegroup]
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "default-to-firewall"
  resource_group_name    = module.avm-res-resources-resourcegroup.name
  route_table_name       = azurerm_route_table.apim.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.avm-res-network-azurefirewall.resource.ip_configuration[0].private_ip_address

  depends_on = [azurerm_route_table.apim, module.avm-res-network-azurefirewall]
}

resource "azurerm_route" "apim_control_plane" {
  name                = "apim-control-plane"
  resource_group_name = module.avm-res-resources-resourcegroup.name
  route_table_name    = azurerm_route_table.apim.name

  # Service tag route
  address_prefix = "ApiManagement"
  next_hop_type  = "Internet"

  depends_on = [azurerm_route_table.apim]
}


module "law" {
  source                                    = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version                                   = "0.5.1"
  name                                      = "IL-log-cind-test"
  location                                  = module.avm-res-resources-resourcegroup.location
  resource_group_name                       = module.avm-res-resources-resourcegroup.name
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = 30
  enable_telemetry                          = false
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
}


module "nsg_default" {
  # This module creates an Azure Network Security Group
  # Source: https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/latest
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  # Network Security Group Configuration
  name                = var.default_nsg_name
  location            = var.resource_group_location
  resource_group_name = module.avm-res-resources-resourcegroup.name
  enable_telemetry    = false

  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
  
  depends_on = [module.avm-res-resources-resourcegroup]
}

resource "azurerm_route_table" "pp_secondary" {
  name                = var.pp_secondary_route_table_name
  location            = local.pp_secondary_region
  resource_group_name = module.avm-res-resources-resourcegroup.name

  depends_on = [module.avm-res-resources-resourcegroup]
  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
}

module "nsg_pp_secondary" {
  # This module creates an Azure Network Security Group
  # Source: https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/latest
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  # Network Security Group Configuration
  name                = var.pp_secondary_nsg_name
  location            = local.pp_secondary_region
  resource_group_name = module.avm-res-resources-resourcegroup.name
  enable_telemetry    = false

  tags = {
    created_by = "terraform"
    Environment = "CCD-test"
  }
  
  depends_on = [module.avm-res-resources-resourcegroup]
}