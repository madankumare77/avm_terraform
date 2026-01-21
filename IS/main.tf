

data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"   #"madan-test"
}
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
# data "azurerm_virtual_network" "existing" {
#   for_each = {
#     for vnet_key, v in local.virtual_networks :
#     vnet_key => v
#     if try(v.create_vnet, false) == false
#   }

#   name = each.value.name
#   resource_group_name = coalesce(
#     try(each.value.resource_group_name, null),
#     data.azurerm_resource_group.rg.name
#   )
# }


# data "azurerm_subnet" "existing" {
#   # Build a flat map of "<vnet_key>:<subnet_key>" => details, directly inline
#   for_each = {
#     for pair in flatten([
#       for vnet_key, v in local.virtual_networks : (
#         try(v.create_vnet, false) == false ?
#         [
#           for subnet_key, s in try(v.existing_subnets, {}) : {
#             vnet_key    = vnet_key
#             subnet_key  = subnet_key
#             vnet_rg     = coalesce(try(v.resource_group_name, null), data.azurerm_resource_group.rg.name)
#             vnet_name   = v.name
#             subnet_name = s.name
#           }
#         ] : []
#       )
#     ]) :
#     "${pair.vnet_key}:${pair.subnet_key}" => pair
#   }

#   name                 = each.value.subnet_name
#   resource_group_name  = each.value.vnet_rg
#   virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
# }

#data.azurerm_virtual_network.existing["vnet1_manual"].id
#data.azurerm_subnet.existing["vnet1_manual:snet1"].id
#data.azurerm_subnet.existing["vnet1_manual:snet2"].id


#--------------------------------------------------------------------
# Network Security Group
#--------------------------------------------------------------------
# 4) Lookup only for create_nsg=false
# data "azurerm_network_security_group" "existing" {
#   for_each            = { for k, v in local.nsg_lookup : k => v }
#   name                = each.value.nsg_name
#   resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
# }

# output "nsg_ids" {
#   value = local.nsg_ids
# }

#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
# module "avm-res-managedidentity-userassignedidentity" {
#   source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
#   version             = "0.3.4"
#   for_each            = { for k, v in local.user_assigned_identities : k => v }
#   name                = each.value.name
#   location            = each.value.location
#   resource_group_name = each.value.resource_group_name
#   enable_telemetry    = false
#   tags = (
#     try(each.value.tags, null) == null
#     ? null
#     : { for k, v in each.value.tags : k => tostring(v) }
#   )
# }

#--------------------------------------------------------------------
# AKS
#--------------------------------------------------------------------
#note:
#1: dns_prefix_private_cluster required private_dns_zone_id
#2: if local_account_disabled true then role_based_access_control_enabled must be true and it required azure_active_directory_role_based_access_control
#3: api_server_access_profile required then subnet is not allowed to be same with agent node subnet
# module "avm-res-containerservice-managedcluster" {
#   source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
#   version = "0.3.3"
#   for_each = { for k, v in local.aks_configs : k => v }

#   name                       = each.value.name
#   location                   = data.azurerm_resource_group.rg.location
#   resource_group_name        = each.value.resource_group_name
#   kubernetes_version         = each.value.kubernetes_version # optional; omit to use default
#   sku_tier                   = each.value.sku_tier   # "Free" | "Standard" (AKS Uptime SLA)
#   enable_telemetry           = false    
#   oidc_issuer_enabled        = each.value.oidc_issuer_enabled
#   workload_identity_enabled  = each.value.workload_identity_enabled
#   azure_policy_enabled       = each.value.azure_policy_enabled
#   #dns_prefix_private_cluster = "dr-aks-03"
#   #private_dns_zone_id        = local.private_dns_ids["aks"] 
#   dns_prefix = each.value.dns_prefix

#   local_account_disabled = each.value.local_account_disabled
#   role_based_access_control_enabled = each.value.role_based_access_control_enabled #Enabling Azure Active Directory integration requires that `role_based_access_control_enabled` be set to true."
#   # azure_active_directory_role_based_access_control = {
#   #   tenant_id = data.azurerm_client_config.current.tenant_id
#   #   admin_group_object_ids = []  #["<AAD-Group-Object-ID>"]
#   #   azure_rbac_enabled = true
#   # }

#   network_profile = {
#     network_plugin      = each.value.network_profile.network_plugin      # "azure" (CNI) or "kubenet"
#     network_policy      = each.value.network_profile.network_policy      # "azure" | "calico" (depends on plugin/region)
#     ebpf_data_plane     = each.value.network_profile.ebpf_data_plane     # "cilium" (preview in some regions) or null
#     network_plugin_mode = each.value.network_profile.network_plugin_mode # "overlay"
#     dns_service_ip      = each.value.network_profile.dns_service_ip
#     service_cidr        = each.value.network_profile.service_cidr
#     outbound_type     = each.value.network_profile.outbound_type # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
#     load_balancer_sku = each.value.network_profile.load_balancer_sku     # "Basic" | "standard"
#   }

#   default_node_pool = {
#     name            = each.value.default_node_pool.name
#     vm_size         = each.value.default_node_pool.vm_size
#     os_disk_size_gb = each.value.default_node_pool.os_disk_size_gb
#     os_disk_type    = each.value.default_node_pool.os_disk_type # "Managed"|"Ephemeral"
#     zones           = each.value.default_node_pool.zones
#     min_count            = each.value.default_node_pool.min_count # set both min/max to enable cluster autoscaler
#     type                 = each.value.default_node_pool.type  # "VirtualMachineScaleSets" | "AvailabilitySet"
#     max_count            = each.value.default_node_pool.max_count
#     auto_scaling_enabled = each.value.default_node_pool.auto_scaling_enabled
#     max_pods             = each.value.default_node_pool.max_pods
#     vnet_subnet_id       = each.value.default_node_pool.vnet_subnet_id
#     orchestrator_version = null # inherit cluster version if null
#     # Optional
#     kubelet_config = {
#       cpu_manager_policy        = null
#       cpu_cfs_quota_enabled     = null
#       cpu_cfs_quota_period      = null
#       image_gc_high_threshold   = 85
#       image_gc_low_threshold    = 70
#       topology_manager_policy   = null
#       allowed_unsafe_sysctls    = []
#       container_log_max_size_mb = 25
#       container_log_max_line    = 5
#     }
#     linux_os_config = {
#       swap_file_size_mb = 0
#       sysctl_config = {
#         net_core_somaxconn           = 16384
#         net_ipv4_tcp_tw_reuse        = false
#         net_ipv4_ip_local_port_range = "1024 65535"
#       }
#       transparent_huge_page_defrag = "madvise"
#     }
#     upgrade_settings = {
#       drain_timeout_in_minutes      = 0
#       node_soak_duration_in_minutes = 0
#       max_surge                     = "10%"
#     }
#     node_labels = (
#       try(each.value.default_node_pool.node_labels, null) == null
#       ? null
#       : { for k, v in each.value.default_node_pool.node_labels : k => tostring(v) }
#     )
#     node_taints = [] # e.g., ["CriticalAddonsOnly=true:NoSchedule"]
#   }

#   # Additional user pools (Portal: Node pools → Add node pool)
#   node_pools = {
#     for np_key, np_value in try(each.value.node_pools, {}) : np_key => {
#       name    = np_value.name
#       vm_size = np_value.vm_size
#       mode    = np_value.mode  # "System" | "User"
#       min_count            = np_value.min_count
#       max_count            = np_value.max_count
#       auto_scaling_enabled = np_value.auto_scaling_enabled
#       vnet_subnet_id       = np_value.vnet_subnet_id
#       os_sku               = np_value.os_sku       # "Ubuntu" | "CBLMariner"
#       os_type              = np_value.os_type      # "Linux" | "Windows"
#       os_disk_size_gb      = np_value.os_disk_size_gb
#       os_disk_type         = np_value.os_disk_type # "Managed" | "Ephemeral"
#       max_pods             = np_value.max_pods
#       node_labels = (
#         try(np_value.node_labels, null) == null
#         ? null
#         : { for k, v in np_value.node_labels : k => tostring(v) }
#       )
#       node_taints          = try(np_value.node_taints, [])
#       zones                = np_value.zones
#       upgrade_settings = {
#         drain_timeout_in_minutes      = 0
#         node_soak_duration_in_minutes = 0
#         max_surge                     = "10%"
#       }
#     }
#   }

#   managed_identities = {
#     user_assigned_resource_ids = toset([
#       for id_key in try(each.value.user_assigned_identity_keys, []) :
#       module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
#     ])
#   }

#   tags = (
#     try(each.value.tags, null) == null
#     ? null
#     : { for k, v in each.value.tags : k => tostring(v) }
#   )

#   # API server access (Basics → API server)
#   # api_server_access_profile = {
#   #   authorized_ip_ranges = [ # Only for Public clusters
#   #     # "x.x.x.x/32"
#   #   ]
#   #   subnet_id                           = data.azurerm_subnet.existing["vnet1_manual:snet1"].id # Required if enable_vnet_integration=true
#   #   virtual_network_integration_enabled = true
#   # }
# }




variable "wi_namespace" {
  type        = string
  default     = "default"
  description = "Namespace for ServiceAccount used with Workload Identity"
}

variable "wi_service_account" {
  type        = string
  default     = "workload-sa"
  description = "ServiceAccount name used with Workload Identity"
}
#kubectl create serviceaccount workload-sa -n mk

# resource "azurerm_federated_identity_credential" "wi_app_fic" {
#   name                = "wi-app-fic"
#   resource_group_name = data.azurerm_resource_group.rg.name
#   parent_id           = module.avm-res-managedidentity-userassignedidentity["aks"].resource_id
#   audience            = ["api://AzureADTokenExchange"]

#   issuer  = module.avm-res-containerservice-managedcluster["dr_aks"].oidc_issuer_url
#   subject = "system:serviceaccount:${var.wi_namespace}:${var.wi_service_account}"
# }

locals {
  sqlmi-configs = {
    sqlmi_1 = {
      name = "sql-mk-01"
      location = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      #subnet_id = data.azurerm_subnet.existing["vnet1_manual:snet3"].id  #subnet should be delegated to Microsoft.Sql/managedInstances and nsg rules applied as per sql mi requirements
      administrator_login          = "sqladminuser"
      administrator_login_password = "Cricket@#12345678"
      sku_name                     = "GP_Gen5"
      vcores = 4
      storage_size_in_gb = 128
      license_type = "LicenseIncluded"
      timezone_id = "India Standard Time"
      proxy_override               = "Proxy"
      public_data_endpoint_enabled = false
      minimum_tls_version          = "1.2" #TLS 1.2 is the minimum supported version
      zone_redundant_enabled         = false
      maintenance_configuration_name = null
      user_assigned_identity_keys                    = ["sqlmi"]
    }
  }
}

# module "avm-res-sql-managedinstance" {
#   source  = "Azure/avm-res-sql-managedinstance/azurerm"
#   version = "0.1.3"
#   for_each = { for k, v in local.sqlmi-configs : k => v }
#   name = each.value.name
#   location = each.value.location
#   resource_group_name = data.azurerm_resource_group.rg.name
#   subnet_id = each.value.subnet_id
#   administrator_login          = each.value.administrator_login
#   administrator_login_password = each.value.administrator_login_password
#   sku_name                     = each.value.sku_name
#   vcores = each.value.vcores
#   storage_size_in_gb = each.value.storage_size_in_gb
#   license_type = each.value.license_type
#   timezone_id = each.value.timezone_id
#   proxy_override               = each.value.proxy_override
#   public_data_endpoint_enabled = each.value.public_data_endpoint_enabled
#   minimum_tls_version          = each.value.minimum_tls_version
#   zone_redundant_enabled         = each.value.zone_redundant_enabled
#   maintenance_configuration_name = each.value.maintenance_configuration_name
#   enable_telemetry    = false
#   managed_identities = {
#     user_assigned_resource_ids = toset([
#       for id_key in try(each.value.user_assigned_identity_keys, []) :
#       module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
#     ])
#   }
#   active_directory_administrator = {
#     azuread_authentication_only = true
#     object_id = "646de4cd-ddd5-4d19-8f29-d92b0f772765"
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     login_username = "v-maeligeti@microsoft.com"
#   }
# }


resource "azurerm_network_security_group" "this" {
  location            = data.azurerm_resource_group.rg.location
  name                = "mi-security-group"
  resource_group_name = data.azurerm_resource_group.rg.name
}


resource "azurerm_network_security_rule" "allow_management_inbound" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "allow_management_inbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 106
  protocol                    = "Tcp"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_ranges     = ["9000", "9003", "1438", "1440", "1452"]
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_misubnet_inbound" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "allow_misubnet_inbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 200
  protocol                    = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/24"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_health_probe_inbound" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "allow_health_probe_inbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 300
  protocol                    = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_tds_inbound" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "allow_tds_inbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 1000
  protocol                    = "Tcp"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  access                      = "Deny"
  direction                   = "Inbound"
  name                        = "deny_all_inbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 4096
  protocol                    = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_management_outbound" {
  access                      = "Allow"
  direction                   = "Outbound"
  name                        = "allow_management_outbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 106
  protocol                    = "Tcp"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_ranges     = ["80", "443", "12000"]
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_misubnet_outbound" {
  access                      = "Allow"
  direction                   = "Outbound"
  name                        = "allow_misubnet_outbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 200
  protocol                    = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/24"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "deny_all_outbound" {
  access                      = "Deny"
  direction                   = "Outbound"
  name                        = "deny_all_outbound"
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 4096
  protocol                    = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_virtual_network" "this" {
  location            = data.azurerm_resource_group.rg.location
  name                = "vnet-mi"
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "this" {
  address_prefixes     = ["10.1.0.0/24"]
  name                 = "subnet-mi"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.this.name

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name    = "Microsoft.Sql/managedInstances"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.this.id
}

resource "azurerm_route_table" "this" {
  location                      = data.azurerm_resource_group.rg.location
  name                          = "routetable-mi"
  resource_group_name           = data.azurerm_resource_group.rg.name
  bgp_route_propagation_enabled = false

  depends_on = [
    azurerm_subnet.this,
  ]
}

resource "azurerm_subnet_route_table_association" "this" {
  route_table_id = azurerm_route_table.this.id
  subnet_id      = azurerm_subnet.this.id
}

resource "azurerm_user_assigned_identity" "uami" {
  location            = data.azurerm_resource_group.rg.location
  name                = "sql-user-identity"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "random_password" "myadminpassword" {
  length           = 16
  override_special = "@#%*()-_=+[]{}:?"
  special          = true
}

# This is the module call
module "sqlmi_test" {
  source = "Azure/avm-res-sql-managedinstance/azurerm"
  version = "0.1.3"

  administrator_login          = "mkuseradmin"
  administrator_login_password = random_password.myadminpassword.result
  license_type                 = "LicenseIncluded"
  location                     = data.azurerm_resource_group.rg.location
  name                         = "sqlmimkinfy001"
  resource_group_name          = data.azurerm_resource_group.rg.name
  sku_name                     = "GP_Gen5"
  storage_size_in_gb           = 32
  subnet_id                    = azurerm_subnet.this.id
  vcores                       = "4"
  enable_telemetry    = false
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.uami.id]
  }
  zone_redundant_enabled = true
  active_directory_administrator = {
    azuread_authentication_only = true
    object_id = "646de4cd-ddd5-4d19-8f29-d92b0f772765"
    tenant_id = data.azurerm_client_config.current.tenant_id
    login_username = "v-maeligeti@microsoft.com"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.this,
    azurerm_subnet_route_table_association.this,
  ]
}