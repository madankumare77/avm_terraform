locals {
  virtual_networks = {
    vnet-primary = {
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
        # snetpsql = {
        #   name           = "subnet-psql"
        #   address_prefix = ["10.0.1.0/24"]

        #   delegation = {
        #     name = "postgres-delegation"
        #     service_delegation = {
        #       name    = "Microsoft.DBforPostgreSQL/flexibleServers"
        #       actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
        #     }
        #   }
        # }
        # snetpsql2 = {
        #   name           = "subnet-psql2"
        #   address_prefix = ["10.0.1.0/24"]

        #   delegation = {
        #     name = "postgres-delegation"
        #     service_delegation = {
        #       name    = "Microsoft.DBforPostgreSQL/flexibleServers"
        #       actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
        #     }
        #   }
        # }
        snetpe = {
          name           = "subnet-pe"
          address_prefix = ["10.0.2.0/24"]
          #nsg_key        = "nsg_primary"
        }
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

