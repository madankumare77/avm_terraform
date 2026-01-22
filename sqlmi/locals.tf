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
    vnet-dr = {
      create_vnet            = true
      parent_id             = data.azurerm_resource_group.rg_dr.id
      name                   = "vent-infy-is-dr"
      #location               = data.azurerm_resource_group.rg_dr.location
      location = "japaneast"
      address_space          = ["10.1.0.0/24"]
      enable_ddos_protection = false
      dns_servers            = ["168.63.129.16"]
      tags = {
        created_by = "terraform"
      }
      subnet_configs = {
        snetmi = {
          name           = "subnet-mi"
          address_prefix = ["10.1.0.0/26"]
          nsg_key        = "nsg_dr"
          route_table   = { id = module.avm-res-network-routetable.resource_id }

          delegation = {
            name = "managedinstancedelegation"
            service_delegation = {
              name    = "Microsoft.Sql/managedInstances"
              actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
            }
          }
        }
        snet1 = {
          name           = "subnet-pvt"
          address_prefix = ["10.1.0.64/26"]
          nsg_key        = "nsg_dr"
          route_table   = { id = module.avm-res-network-routetable.resource_id }
        }
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
    nsg_dr = {
      create_nsg = true
      nsg_name   = "mi-security-group-dr"
      #location   = data.azurerm_resource_group.rg_dr.location
      location = "japaneast"
      rg_name    = data.azurerm_resource_group.rg_dr.name

      security_rules = [
        {
          name                       = "allow_management_inbound"
          priority                   = 106
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          source_port_range          = "*"
          destination_port_ranges    = ["9000", "9003", "1438", "1440", "1452"]
        },
        {
          name                       = "allow_misubnet_inbound"
          priority                   = 200
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "10.1.0.0/24"
          source_port_range          = "*"
          destination_port_range     = "*"
        },
        {
          access                     = "Allow"
          direction                  = "Inbound"
          name                       = "allow_health_probe_inbound"
          priority                   = 300
          protocol                   = "*"
          destination_address_prefix = "*"
          destination_port_range     = "*"
          source_address_prefix      = "AzureLoadBalancer"
          source_port_range          = "*"

        },
        {
          access                     = "Allow"
          direction                  = "Inbound"
          name                       = "allow_tds_inbound"
          priority                   = 1000
          protocol                   = "Tcp"
          destination_address_prefix = "*"
          destination_port_range     = "1433"
          source_address_prefix      = "VirtualNetwork"
          source_port_range          = "*"

        },
        {
          access                     = "Deny"
          direction                  = "Inbound"
          name                       = "deny_all_inbound"
          priority                   = 4096
          protocol                   = "*"
          destination_address_prefix = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          source_port_range          = "*"
        },
        {
          access                     = "Allow"
          direction                  = "Outbound"
          name                       = "allow_management_outbound"
          priority                   = 106
          protocol                   = "Tcp"
          destination_address_prefix = "*"
          destination_port_ranges    = ["80", "443", "12000"]
          source_address_prefix      = "*"
          source_port_range          = "*"
        },
        {
          access                     = "Allow"
          direction                  = "Outbound"
          name                       = "allow_misubnet_outbound"
          priority                   = 200
          protocol                   = "*"
          destination_address_prefix = "*"
          destination_port_range     = "*"
          source_address_prefix      = "10.1.0.64/26"
          source_port_range          = "*"
        },
        {
          access                     = "Deny"
          direction                  = "Outbound"
          name                       = "deny_all_outbound"
          priority                   = 4096
          protocol                   = "*"
          destination_address_prefix = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          source_port_range          = "*"
        }
      ]
      tags = {
        created_by = "terraform"
      }
    }
  }
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
    secondary = {
      name                = "mi-sqlmi-identity-dr"
      # location            = data.azurerm_resource_group.rg_dr.location
      location = "japaneast"
      resource_group_name = data.azurerm_resource_group.rg_dr.name
    }

  }
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
      private_endpoints_manage_dns_zone_group = true
      private_endpoints = {
        sqlmipe = {
          name                          = "pvt-endpoint-sqlmi001"
          vnet_key                      = "vnet1"
          subnet_key                    = "snet1"
          subresource_name              = "managedInstance"
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
  sqlmi-configs-secondary = {
    sqlmi_dr = {
      name                = "sql-mk-infy-01-dr"
      #location            = data.azurerm_resource_group.rg_dr.location
      location = "japaneast"
      resource_group_name = data.azurerm_resource_group.rg_dr.name
      subnet_id = local.subnet_ids["vnet-dr.snetmi"]  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
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
      user_assigned_identity_keys  = ["secondary"]
      private_endpoints_manage_dns_zone_group = true
      dns_zone_partner_id = module.sqlmi_test["sqlmi_1"].resource_id
      private_endpoints = {
        sqlmipe = {
          name                          = "pvt-endpoint-sql-mk-infy-01-dr"
          vnet_key                      = "vnet-dr"
          subnet_key                    = "snet1"
          subresource_name              = "managedInstance"
          #private_dns_zone_resource_ids = [local.private_dns_ids["cosmosdb"]]
        }
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-di-sql-mk-infy-01-dr"
          workspace_resource_id = try(module.law[0].resource_id, null)
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


