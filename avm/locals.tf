locals {
  virtual_networks = {
    vnet1 = {
      create_vnet            = true
      name                   = "vent-name"
      location               = "centralindia"
      address_space          = ["101.122.96.0/24"]
      enable_ddos_protection = false
      dns_servers            = ["168.63.129.16"]
      tags = {
        created_by = "terraform"
      }

      subnet_configs = {
        snet1 = {
          name              = "snet1-test"
          address_prefix    = ["101.122.96.0/28"]
          service_endpoints = ["Microsoft.KeyVault"]
          nsg_key = "nsg1"
        }

        snet2 = {
          name           = "snet2-test"
          address_prefix = ["101.122.96.64/28"]
          nsg_key = "nsg2"
        }

        snet3 = {
          name              = "snet3-test"
          address_prefix    = ["101.122.96.32/28"]
          service_endpoints = ["Microsoft.Web"]
          nsg_key = "nsg2"

          delegation = {
            name = "functionapp"
            service_delegation = {
              name    = "Microsoft.Web/serverFarms"
              actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
            }
          }
        }
      }
    }

    vnet2 = {
      create_vnet            = true
      name                   = "vent2-name"
      location               = "centralindia"
      address_space          = ["101.123.96.0/24"]
      enable_ddos_protection = false
      tags = { created_by = "terraform" }

      subnet_configs = {
        snet1 = {
          name              = "snet1-test"
          address_prefix    = ["101.123.96.0/28"]
          service_endpoints = ["Microsoft.KeyVault"]
          nsg_key = "nsg1"
        }
      }
    }
    # vnet1_manual = {
    #   create_vnet = false
    #   name                = "vnet1-manual"
    #   resource_group_name = data.azurerm_resource_group.rg.name

    #   # list the subnets you want to reference from that existing vnet
    #   existing_subnets = {
    #     snet1 = { name = "snet1-manual" }
    #     snet2 = { name = "snet2-manual" }
    #   }
    # }
  }
}
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


locals {
  nsg_configs = {
    nsg1 = {
      create_nsg     = true
      nsg_name       = "nsg-infy-test"
      location       = data.azurerm_resource_group.rg.location
      rg_name        = data.azurerm_resource_group.rg.name

      security_rules = [
        {
          name                       = "Allow-InBound"
          priority                   = 500
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "VirtualNetwork"
          source_port_range          = "*"
          destination_port_range     = "443"
        }
      ]
      tags = {
        created_by = "terraform"
      }
    }

    nsg2 = {
      create_nsg = false
      nsg_name   = "nsg-infy-manual"
      rg_name    = data.azurerm_resource_group.rg.name
      # location optional for lookup; NSG has a location but data source doesn't need it
    }
  }

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
}
# 5) Unified outputs (IDs of created + existing)
locals {
  nsg_ids = merge(
    { for k, m in module.nsg : k => m.resource_id },
    { for k, d in data.azurerm_network_security_group.existing : k => d.id }
  )
}