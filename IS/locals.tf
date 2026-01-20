#--------------------------------------------------------------------
# Virtual Network and Subnet configurations
#--------------------------------------------------------------------
locals {
  virtual_networks = {
    vnet1_manual = {
      create_vnet         = false
      name                = "vnet1-manual"
      resource_group_name = data.azurerm_resource_group.rg.name

      # list the subnets you want to reference from that existing vnet
      existing_subnets = {
        snet1 = { name = "snet1-manual" }
        snet2 = { name = "snet2-manual" }
      }
    }
  }
}

#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
    nsg2 = {
      create_nsg = false
      nsg_name   = "nsg-infy-manual"
      rg_name    = data.azurerm_resource_group.rg.name
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
    wi_app = {
      name                = "mi-wi-app-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }

  }
}


#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------


locals {
  private_dns_zones = {
    aks = {
      create_private_dns_zone = false
      private_dns_zone_name   = "privatelink.centralindia.azmk8s.io"
      resource_group_name     = data.azurerm_resource_group.rg.name
    }
  }
  private_dns_ids = merge(
    { for k, m in module.avm-res-network-privatednszone : k => m.resource_id },
    { for k, d in data.azurerm_private_dns_zone.existing : k => d.id }
  )
}
#--------------------------------------------------------------------
# Private DNS zone avm module to create and data block to use existing.
#--------------------------------------------------------------------
module "avm-res-network-privatednszone" {
  source           = "Azure/avm-res-network-privatednszone/azurerm"
  version          = "0.4.4"
  for_each         = { for k, v in local.private_dns_zones : k => v if v.create_private_dns_zone }
  enable_telemetry = false
  domain_name      = each.value.private_dns_zone_name
  parent_id        = data.azurerm_resource_group.rg.id
  virtual_network_links = {
    vnet_link = {
      name                 = "${each.value.private_dns_zone_name}-vnetlink"
      virtual_network_id   = each.value.vnet_id
      registration_enabled = false
    }
  }
}
data "azurerm_private_dns_zone" "existing" {
  for_each            = { for k, v in local.private_dns_zones : k => v if !v.create_private_dns_zone }
  name                = each.value.private_dns_zone_name
  resource_group_name = each.value.resource_group_name
}

data "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.centralindia.azmk8s.io"
  resource_group_name = data.azurerm_resource_group.rg.name
}