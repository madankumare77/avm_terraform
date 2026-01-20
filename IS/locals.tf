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
# NSG Locals to check the condition to create or use existing
#--------------------------------------------------------------------
locals {
  nsg_lookup = {
    for k, v in local.nsg_configs : k => v
    if !try(v.create_nsg, true)
  }
  nsg_ids = merge(
    #{ for k, m in module.nsg : k => m.resource_id },
    { for k, d in data.azurerm_network_security_group.existing : k => d.id }
  )
}

locals {
  user_assigned_identities = {
    aks = {
      name                = "mi-aks-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }
  }
}

#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
locals {
  aks_configs = {
    dr_aks = {
      name = "dr-aks-03"
      resource_group_name = data.azurerm_resource_group.rg.name
      location = data.azurerm_resource_group.rg.location
      kubernetes_version         = "1.34.1"
      sku_tier                   = "Free"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = true
      dns_prefix = "dr-aks-03"
      local_account_disabled = false
      role_based_access_control_enabled = false
      user_assigned_identity_keys                    = ["aks"]
      default_node_pool = {
        name            = "systemnp"
        vm_size         = "Standard_DS3_v2"
        os_disk_size_gb = 128
        os_disk_type    = "Managed"
        zones           = ["1", "2", "3"]
        min_count            = 3
        type                 = "VirtualMachineScaleSets"
        max_count            = 5
        auto_scaling_enabled = true
        max_pods             = 110
        vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
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
          vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
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
        np2 = {
          name    = "usernp2"
          vm_size = "Standard_D4s_v5"
          mode    = "User"
          min_count            = 2
          max_count            = 10
          auto_scaling_enabled = true
          vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
          os_sku               = "Ubuntu"
          os_type              = "Linux"
          os_disk_size_gb      = 128
          os_disk_type         = "Managed"
          max_pods             = 110
          zones                = ["1", "2", "3"]
        }
      }
      network_profile = {
        network_plugin      = "azure"          # "azure" (CNI) or "kubenet"
        network_policy      = "azure"          # "azure" | "calico" (depends on plugin/region)
        ebpf_data_plane     = "cilium"         # "cilium" (preview in some regions) or null
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.2.0.10"
        service_cidr        = "10.2.0.0/24"
        outbound_type     = "loadBalancer"
        load_balancer_sku = "standard"
      }
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }

    }
  }
}




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