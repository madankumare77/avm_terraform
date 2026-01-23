# SQL Managed instance
1. Rquired vnet, delegated subnet, nsg with dedicated nsg rules, route table
2. 

1. for gro replication failover, 
The managed instance you choose as the secondary must be from a different region. The secondary also needs to be an empty managed instance that has the same max-size and dns-prefix as the primary.

vnet peering required, no overlaping of address spaces.

For SQL Managed Instance, the backup redundancy can be LRS / ZRS / GRS / GZRS, but ZRS/GZRS are only available in certain regions. If your module’s default is ZRS (common), creating in South India (or another region without ZRS for MI backups) will fail exactly like this. The safe, broadly supported choice is GRS; use that or another redundancy explicitly supported in your region


2. Failover Groups do not require paired regions.
They only require:

Two SQL Managed Instances
In two Azure regions
VNet connectivity (peering/VPN/ExpressRoute)
Same DNS Zone (secondary must be created using dns_zone_partner_id)
if managed dns zone then this dns zone required to integate with both vnets.
Same storage size
Secondary is empty
Both VNets non-overlapping
Required NSG ports open: 5022 and 11000–11999

So Central India → South India failover is supported as long as quota exists in South India.






#############################################################################################
#############################################################################################
# - `virtual_networks`
#  Full example: locals.virtual_networks
How module works (main.tf behavior)
change enable_virtual_networks = true 

For create_vnet=true → AVM VNet module runs.
For create_vnet=false → data sources fetch VNet + subnets.
local.subnet_ids merges created + existing subnet IDs so downstream resources can use:

"${vnet_key}.${subnet_key}" → e.g. "vnet1_manual.snet1"

1. To create new vnet make create_vnet = true and use following configuration example

locals {
  virtual_networks = {
    # -------------------------------
    # CREATE NEW VNET
    # -------------------------------
    vnet1 = {
      create_vnet            = true
      name                   = "vent-name"
      location               = "centralindia"
      address_space          = ["101.122.96.0/24"]
      enable_ddos_protection = false
      # Optional (module input requires special shaping in main.tf)
      dns_servers = ["168.63.129.16"]
      tags = {
        created_by = "terraform"
      }
      subnet_configs = {
        snet1 = {
          name              = "snet1-test"
          address_prefix    = ["101.122.96.0/28"]
          service_endpoints = ["Microsoft.KeyVault"]
          nsg_key           = "nsg1"
        }
        snet2 = {
          name           = "snet2-test"
          address_prefix = ["101.122.96.64/28"]
          nsg_key        = "nsg2"
        }
        snet3 = {
          name              = "snet3-test"
          address_prefix    = ["101.122.96.32/28"]
          service_endpoints = ["Microsoft.Web"]
          nsg_key           = "nsg2"

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

2. To use existing vnet make create_vnet = false and use following configuration example
    # -------------------------------
    # B. USE EXISTING VNET + SUBNETS
    # -------------------------------
    vnet1_manual = {
      create_vnet         = false
      name                = "vnet1-manual"
      resource_group_name = data.azurerm_resource_group.rg.name

      existing_subnets = {
        snet1 = { name = "snet1-manual" }
        snet2 = { name = "snet2-manual" }
      }
    }
  }
}



# - `nsg_configs`
# Full example: locals.nsg_configs
How module works (main.tf behavior)
change enable_nsg = true 

For create_nsg=true → AVM nsg module runs.
For create_nsg=false → data sources fetch nsg configuration.

1. To create new nsg make create_nsg = true and use following configuration example
locals {
  nsg_configs = {
    # -------------------------------
    # CREATE NEW NSG
    # -------------------------------
    nsg1 = {
      create_nsg = true
      nsg_name   = "nsg-infy-test"
      location   = data.azurerm_resource_group.rg.location
      rg_name    = data.azurerm_resource_group.rg.name

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
2. To use existing nsg make create_nsg = false and use following configuration example
    # -------------------------------
    # B. USE EXISTING NSG
    # -------------------------------
    nsg2 = {
      create_nsg = false
      nsg_name   = "nsg-infy-manual"
      rg_name    = data.azurerm_resource_group.rg.name
    }
  }
}


# - 'sqlmi-configs'

locals {
  sqlmi-configs = {
    sqlmi_primary = {
      name                = "sql-mk-primary-01"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      subnet_id = local.subnet_ids["vnet-primary.snetmi"]  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
      administrator_login          = "sqladminuser"
      administrator_login_password = var.sqlmi_adminpass #random_password.myadminpassword.result
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
          vnet_key                      = "vnet-primary"
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
}

  # active_directory_administrator = {
  #   azuread_authentication_only = each.value.active_directory_administrator.azuread_authentication_only
  #   object_id = each.value.active_directory_administrator.object_id
  #   tenant_id = each.value.active_directory_administrator.tenant_id
  #   login_username = each.value.active_directory_administrator.login_username
  # }

#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
1. dns_prefix = "The DNS prefix specified when creating the managed cluster. If you do not specify one, a random prefix will be generated."

2. dns_prefix_private_cluster = "The Private Cluster DNS prefix specified when creating a private cluster. Required if deploying private cluster and providing a private dns zone id(private_dns_zone_id)."


locals {
  aks_configs = {
    aks_dr = {
      name = "aks-dr-001"
      resource_group_name = data.azurerm_resource_group.rg.name
      location = data.azurerm_resource_group.rg.location
      kubernetes_version         = "1.34.1"
      sku_tier                   = "Free"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = true
      dns_prefix = "aks-dr-001"
      local_account_disabled = false
      role_based_access_control_enabled = false
      user_assigned_identity_keys                    = ["aks"]
      default_node_pool = {
        name            = "systemnp"
        vm_size         = "standard_b2ms"
        os_disk_size_gb = 128
        os_disk_type    = "Managed"
        #zones           = ["1", "2", "3"]
        min_count            = 3
        type                 = "VirtualMachineScaleSets"
        max_count            = 5
        auto_scaling_enabled = true
        max_pods             = 110
        vnet_subnet_id       = local.subnet_ids["vnet-primary.snet2"]
        node_labels = {
          "nodepool-type" = "system"
        }
      }
      node_pools = {
        np1 = {
          name    = "usernp1"
          vm_size = "Standard_D4s_v5"
          mode    = "User"
          min_count            = 2
          max_count            = 10
          auto_scaling_enabled = true
          vnet_subnet_id       = data.azurerm_subnet.existing["vnet-primary:snet2"].id
          os_sku               = "Ubuntu"
          os_type              = "Linux"
          os_disk_size_gb      = 128
          os_disk_type         = "Managed"
          max_pods             = 110
          node_labels = {
            "workload" = "apps"
          }
          node_taints          = ["infysvc=true:NoSchedule"]
          zones                = ["1", "2", "3"]
        }
      }
      network_profile = {
        network_plugin      = "azure"          # "azure" (CNI) or "kubenet"
        network_policy      = "azure"          # "azure" | "calico" (depends on plugin/region)
        ebpf_data_plane     = "cilium"         # "cilium" (preview in some regions) or null
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.3.0.10"
        service_cidr        = "10.3.0.0/24"
        outbound_type     = "loadBalancer"
        load_balancer_sku = "standard"
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-aks-dr-001cd"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }

    }
  }
}


data "azuread_group" "sql_admins" {
  display_name   = "infy-test"
  security_enabled = true
}


###############################################################
resource "random_password" "myadminpassword" {
  length           = 16
  override_special = "@#%*()-_=+[]{}:?"
  special          = true
}