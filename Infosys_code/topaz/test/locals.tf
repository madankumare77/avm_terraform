locals {
  virtual_networks = {
    vnet_aks = {
      create_vnet         = false
      name                = "vnet-cind-topaz-test"
      resource_group_name = data.azurerm_resource_group.rg_vnet.name
 
      existing_subnets = {
        snet_aks = { name = "snet-cind-topaz-test" }
      }
    }
  }
}
 
#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
  }
}
#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    aks = {
      name                = "useridentity-isinfytopaz-test"
      location            = data.azurerm_resource_group.rg_aks.location
      resource_group_name = data.azurerm_resource_group.rg_aks.name
    }
  }
} 
#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
locals {
  aks_configs = {
    aks_topaz = {
      name = "isinfytopaz-test"
      resource_group_name = data.azurerm_resource_group.rg_aks.name
      location = data.azurerm_resource_group.rg_aks.location
      node_resource_group_name   = "rg-aks-assets-isinfytopaz-test"
      kubernetes_version         = "1.33.5"
      sku_tier                   = "Standard"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = false
      http_application_routing_enabled = false  #Since we are using istio ingress gateway application routing not required
      node_os_channel_upgrade    = "None"
      dns_prefix = "isinfytopaz-test"
      local_account_disabled = true
      user_assigned_identity_keys                    = ["aks"]
      private_cluster_enabled    = true                    # force replacement of the cluster if changed
      role_based_access_control_enabled = true                      # force replacement of the cluster if changed
      disk_encryption_set_id = azurerm_disk_encryption_set.example.id
      azure_active_directory_role_based_access_control = {
        tenant_id = data.azurerm_client_config.current.tenant_id
        admin_group_object_ids = try([data.azuread_group.ad_group.object_id], null)
        azure_rbac_enabled = false                         # (false uses Microsoft entra ID authentication with kubernetes RBAC)
      }
      default_node_pool = {
        name            = "platform"
        vm_size         = "Standard_D4ds_v5"
        os_sku          = "AzureLinux"     #AzureLinux
        os_disk_size_gb = 130
        os_disk_type    = "Ephemeral"
        zones           = ["1", "2", "3"]  #South india not supporting for availability zones
        min_count            = 1
        type                 = "VirtualMachineScaleSets"
        max_count            = 3
        auto_scaling_enabled = true
        max_pods             = 90
        only_critical_addons_enabled  = true
        vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
        node_taints          = ["CriticalAddonsOnly=true:NoSchedule"]
      }
      node_pools = {
        np1 = {
          name    = "infytopaz"
          vm_size = "Standard_F8s_v2"
          mode    = "User"
          min_count            = 1
          max_count            = 3
          auto_scaling_enabled = true
          zones           = ["1", "2", "3"]
          vnet_subnet_id       = local.subnet_ids["vnet_aks.snet_aks"]
          os_sku               = "AzureLinux"
          os_type              = "Linux"
          os_disk_size_gb      = 120
          os_disk_type         = "Ephemeral"
          max_pods             = 90
          node_labels = {
            "app" = "infytopaz"
          }
          node_taints          = ["node=infytopaz:NoSchedule"]
        }
      }
      network_profile = {
        network_plugin      = "azure"
        network_policy      = "cilium"
        network_data_plane  = "cilium"  
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.0.0.10"
        service_cidr        = "10.0.0.0/16"
        pod_cidr            = "192.168.0.0/16"
        outbound_type     = "userDefinedRouting"
        load_balancer_sku = "standard"
      }
      oms_agent = {
        log_analytics_workspace_id = try(data.azurerm_log_analytics_workspace.law.id, null)
        msi_auth_for_monitoring_enabled = true
      }
      service_mesh_profile = {
        mode = "Istio"
        revisions = ["asm-1-28"]
        external_ingress_gateway_enabled = false
        internal_ingress_gateway_enabled = false
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-aks-logs"
          storage_account_resource_id = data.azurerm_storage_account.aks_diag_st.id
        }
      }
      tags = {
        created_by  = "terraform"
        INFY_Appmaster_App_Name = "isinfytopaz-test"
        INFY_Appmaster_ID = "NA"
        INFY_BusinessUnit = "IS"
        INFY_CostCenter = "No FR_IS"
        INFY_Environment = "Test"
        INFY_Managed_by = "IS"
        INFY_Owner = "EPM-Cloud@infosys.com"
        INFY_Platform = "Test"
        INFY_ProjectCode = "EPMPRJBE"
        INFY_Provider = "Azure"
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
        rg_name     = vnet.resource_group_name
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
# locals {
#   # 1) Split: create vs lookup
#   nsg_create = {
#     for k, v in local.nsg_configs : k => v
#     if try(v.create_nsg, true)
#   }
#   nsg_lookup = {
#     for k, v in local.nsg_configs : k => v
#     if !try(v.create_nsg, true)
#   }
#   # 2) Convert rules list -> map keyed by rule name
#   nsg_security_rules = {
#     for nsg_key, nsg in local.nsg_create : nsg_key => {
#       for r in try(nsg.security_rules, []) : r.name => {
#         # required fields
#         name      = r.name
#         priority  = r.priority
#         direction = r.direction
#         access    = r.access
#         protocol  = r.protocol
#         # optional fields (pass only if present)
#         source_address_prefix      = try(r.source_address_prefix, null)
#         destination_address_prefix = try(r.destination_address_prefix, null)
#         source_port_range      = try(r.source_port_range, null)
#         destination_port_range = try(r.destination_port_range, null)
#         source_address_prefixes      = try(r.source_address_prefixes, null)
#         destination_address_prefixes = try(r.destination_address_prefixes, null)
#         source_port_ranges           = try(r.source_port_ranges, null)
#         destination_port_ranges      = try(r.destination_port_ranges, null)
#         description = try(r.description, null)
#       }
#     }
#   }
#   # 5) Unified outputs (IDs of created + existing)
#   nsg_ids = merge(
#     { for k, m in module.nsg : k => m.resource_id },
#     { for k, d in data.azurerm_network_security_group.existing : k => d.id }
#   )
# }