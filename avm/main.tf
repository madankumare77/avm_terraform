

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Allow both compatible 3.x and 4.x releases so module constraints can resolve
      version = ">= 3.116.0, < 5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {  }
  subscription_id = "a0b36c09-679f-4dfb-829f-3b6685282dae"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = "madan-test"
}

locals {
  virtual_networks = {
    vnet1 = {
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
  }
}


module "avm_res_network_virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.16.0"

  for_each = local.virtual_networks

  name     = each.value.name
  location = each.value.location
  parent_id = data.azurerm_resource_group.rg.id

  address_space = each.value.address_space

  enable_telemetry        = false
  dns_servers = (try(each.value.dns_servers, null) == null ? null: { dns_servers = each.value.dns_servers })

  tags                    = try(each.value.tags, {})

  # --- Transform your subnet_configs -> module.subnets expected shape ---
  subnets = {
    for sk, s in each.value.subnet_configs : sk => {
      name             = s.name
      address_prefixes = s.address_prefix

      # Convert ["Microsoft.KeyVault","Microsoft.Web"] -> [{service="Microsoft.KeyVault"}, {service="Microsoft.Web"}]
      service_endpoints_with_location = [
        for svc in try(s.service_endpoints, []) : {
          service = svc
          # locations = [each.value.location] # use only if you want location restriction
        }
      ]

      network_security_group = (try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] })

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

# 3) Create NSGs only for create_nsg=true
module "nsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.0"

  for_each = local.nsg_create

  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
  location            = coalesce(try(each.value.location, null), data.azurerm_resource_group.rg.location)
  tags                = try(each.value.tags, null)

  # module expects map of rule objects, not list [1](https://github.com/Azure/terraform-azurerm-avm-res-network-networksecuritygroup)
  security_rules = try(local.nsg_security_rules[each.key], {})

  enable_telemetry = false
}

# 4) Lookup only for create_nsg=false
data "azurerm_network_security_group" "existing" {
  for_each = local.nsg_lookup

  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
}

# 5) Unified outputs (IDs of created + existing)
locals {
  nsg_ids = merge(
    { for k, m in module.nsg : k => m.resource_id },
    { for k, d in data.azurerm_network_security_group.existing : k => d.id }
  )
}

output "nsg_ids" {
  value = local.nsg_ids
}
