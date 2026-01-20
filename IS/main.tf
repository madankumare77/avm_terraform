

data "azurerm_resource_group" "rg" {
  name = "madan-test"
}
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------



data "azurerm_virtual_network" "existing" {
  # Only entries where create_vnet = false
  for_each = {
    for vnet_key, v in local.virtual_networks :
    vnet_key => v
    if try(v.create_vnet, false) == false
  }

  name = each.value.name
  resource_group_name = coalesce(
    try(each.value.resource_group_name, null),
    data.azurerm_resource_group.rg.name
  )
}


data "azurerm_subnet" "existing" {
  # Build a flat map of "<vnet_key>:<subnet_key>" => details, directly inline
  for_each = {
    for pair in flatten([
      for vnet_key, v in local.virtual_networks : (
        try(v.create_vnet, false) == false ?
        [
          for subnet_key, s in try(v.existing_subnets, {}) : {
            vnet_key    = vnet_key
            subnet_key  = subnet_key
            vnet_rg     = coalesce(try(v.resource_group_name, null), data.azurerm_resource_group.rg.name)
            vnet_name   = v.name
            subnet_name = s.name
          }
        ] : []
      )
    ]) :
    "${pair.vnet_key}:${pair.subnet_key}" => pair
  }

  name                 = each.value.subnet_name
  resource_group_name  = each.value.vnet_rg
  virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
}

#data.azurerm_virtual_network.existing["vnet1_manual"].id
#data.azurerm_subnet.existing["vnet1_manual:snet1"].id
#data.azurerm_subnet.existing["vnet1_manual:snet2"].id


#--------------------------------------------------------------------
# Network Security Group
#--------------------------------------------------------------------
# 4) Lookup only for create_nsg=false
data "azurerm_network_security_group" "existing" {
  for_each            = { for k, v in local.nsg_lookup : k => v }
  name                = each.value.nsg_name
  resource_group_name = coalesce(try(each.value.rg_name, null), data.azurerm_resource_group.rg.name)
}

output "nsg_ids" {
  value = local.nsg_ids
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

#--------------------------------------------------------------------
# User Assigned Identity
#--------------------------------------------------------------------
module "avm-res-managedidentity-userassignedidentity" {
  source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version             = "0.3.4"
  for_each            = { for k, v in local.user_assigned_identities : k => v }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

#--------------------------------------------------------------------
# AKS
#--------------------------------------------------------------------
# module "avm-res-containerservice-managedcluster" {
#   source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
#   version = "0.4.0-pre2"
#   # insert the 3 required variables here
#   name = "dr-aks-02"
#   location = data.azurerm_resource_group.rg.location
#   parent_id = data.azurerm_resource_group.rg.id
#   enable_telemetry      = false
#   dns_prefix_private_cluster = "dr-aks-02"
# }


# ─────────────────────────────────────────────────────────────────────────────
# BASICS (Portal: Basics)
# ─────────────────────────────────────────────────────────────────────────────

# module "avm-res-containerservice-managedcluster" {
#   source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
#   version = "0.4.0-pre2"

#   name = "dr-aks-02"
#   location = data.azurerm_resource_group.rg.location
#   parent_id = data.azurerm_resource_group.rg.id
#   kubernetes_version  = "1.30.8"             # optional; omit to use default
#   enable_telemetry    = false
#   #dns_prefix_private_cluster = "dr-aks-02"
#   dns_prefix = "dr-aks-02"

#   # Identity
#   managed_identities = {
#     type = "UserAssigned"                    # or "UserAssigned" or "SystemAssigned, UserAssigned"
#     user_assigned_identities = [ module.avm-res-managedidentity-userassignedidentity["aks"].principal_id ]
#   }

#   # Tags (Basics → Tags)
#   tags = {
#     environment = "dev"
#     owner       = "madan"
#     costcenter  = "cc-001"
#   }

#   # SKU (Optional; Portal: Basics)
#   sku = {
#     name = "Base"                   
#     tier = "Standard"  
#     }                           # "Free" | "Standard" (AKS Uptime SLA)

#   # Availability zones (Basics → Availability zones)
#   #availability_zones = [1, 2, 3]                # for default node pool if supported in region


#   # API server access (Basics → API server)
#   # api_server_access_profile = {
#   #   enable_private_cluster        = false       # true for Private cluster
#   #   enable_vnet_integration       = false       # true if using Private Cluster with VNET Integration
#   #   authorized_ip_ranges          = [           # Only for Public clusters
#   #     # "x.x.x.x/32"
#   #   ]
#   #   subnet_id                     = null        # Required if enable_vnet_integration=true
#   #   #private_dns_zone_id           = null        # Optional: custom Private DNS zone
#   #   enable_private_cluster_public_fqdn = false
#   #   run_command_enabled            = false
#   # }

#   # ───────────────────────────────────────────────────────────────────────────
#   # NODE POOLS (Portal: Node pools)
#   # ───────────────────────────────────────────────────────────────────────────

#   default_node_pool = {
#     name                 = "systemnp"
#     vm_size              = "Standard_DS3_v2"
#     os_disk_size_gb      = 128
#     os_disk_type         = "Managed"           # "Managed"|"Ephemeral"
#     zones                = [1, 2, 3]
#     node_count           = 3
#     min_count            = 1                   # set both min/max to enable cluster autoscaler
#     max_count            = 5
#     auto_scaling_enabled  = true
#     max_pods             = 110
#     vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id

#     #mode                 = "System"            # "System" | "User"
#     orchestrator_version = null                # inherit cluster version if null
#     # Optional
#     kubelet_config = {
#       cpu_manager_policy      = null
#       cpu_cfs_quota_enabled   = null
#       cpu_cfs_quota_period    = null
#       image_gc_high_threshold = 85
#       image_gc_low_threshold  = 70
#       topology_manager_policy = null
#       allowed_unsafe_sysctls  = []
#       container_log_max_size_mb = 25
#       container_log_max_line   = 5
#       # eviction_hard, eviction_soft, etc., can be added if needed
#     }
#     linux_os_config = {
#       swap_file_size_mb = 0
#       sysctl_config = {
#         net_core_somaxconn       = 16384
#         net_ipv4_tcp_tw_reuse    = false
#         net_ipv4_ip_local_port_range = "1024 65535"
#       }
#       transparent_huge_page_defrag = "madvise"
#     }
#     node_labels = {
#       "nodepool-type" = "system"
#     }
#     node_taints = [] # e.g., ["CriticalAddonsOnly=true:NoSchedule"]
#   }

#   # Additional user pools (Portal: Node pools → Add node pool)
#   node_pools = {
#     np1 ={
#       name                 = "usernp1"
#       vm_size              = "Standard_D4s_v5"
#       mode                 = "User"
#       node_count           = 2
#       min_count            = 1
#       max_count            = 10
#       auto_scaling_enabled  = true
#       vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
#       os_disk_size_gb      = 128
#       os_disk_type         = "Managed"
#       max_pods             = 110
#       #kubelet_config       = null
#       #linux_os_config      = null
#       node_labels = {
#         "workload" = "apps"
#       }
#       node_taints = []
#       zones       = [1, 2, 3]
#       orchestrator_version = null
#       # Spot example:
#       # scale_set_priority       = "Spot"
#       # eviction_policy          = "Delete"
#       # spot_max_price           = -1
#     }
#   }

#   # ───────────────────────────────────────────────────────────────────────────
#   # ACCESS (Portal: Access)
#   # ───────────────────────────────────────────────────────────────────────────


#   # AAD integration (Managed AAD)


#   oidc_issuer_enabled = true
#   workload_identity_enabled = false

#   # ───────────────────────────────────────────────────────────────────────────
#   # NETWORKING (Portal: Networking)
#   # ───────────────────────────────────────────────────────────────────────────

#   network_profile = {
#     network_plugin    = "azure"              # "azure" (CNI) or "kubenet"
#     network_policy    = "azure"              # "azure" | "calico" (depends on plugin/region)
#     ebpf_data_plane   = "cilium"                 # "cilium" (preview in some regions) or null
#     network_plugin_mode = "overlay"
#     dns_service_ip    = "10.2.0.10"
#     service_cidr      = "10.2.0.0/24"
#     #docker_bridge_cidr= "172.17.0.1/16"
#     outbound_type     = "loadBalancer"       # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
#     load_balancer_sku = "standard"          # "Basic" | "standard"
#     # load_balancer_profile = {
#     #   managed_outbound_ip_count = 2
#     #   idle_timeout_in_minutes   = 30
#     #   outbound_ports_allocated  = 1024
#     #   # managed_outbound_ipv6_count = 0
#     #   # outbound_ip_prefix_ids     = []
#     #   # outbound_ip_address_ids    = []
#     # }
#     pod_cidr          = null                 # for kubenet
#     pod_cidrs         = null
#     service_cidrs     = null
#   }

#   # Private cluster DNS/Link settings are in api_server_access_profile above.

#   # ───────────────────────────────────────────────────────────────────────────
#   # INTEGRATIONS (Portal: Integrations)
#   # ───────────────────────────────────────────────────────────────────────────

#   # Container insights (Monitor)
#   # oms_agent = {
#   #   enabled                    = true
#   #   log_analytics_workspace_id = "<log-analytics-workspace-id>"
#   # }

#   # Azure Policy for AKS
#   azure_policy_enabled = true

#   # Key Vault Secrets Provider
#   # key_vault_secrets_provider = {
#   #   enabled = true
#   #   secret_rotation_enabled = true
#   #   rotation_poll_interval  = "2m"
#   # }

#   # Ingress Application Gateway (AGIC) – optional
#   # ingress_application_gateway = {
#   #   enabled              = false
#   #   # application_gateway_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/applicationGateways/<agic>"
#   #   # subnet_cidr           = null # for create-new scenarios (if module supports)
#   #   # subnet_id             = null
#   # }

#   # Open Service Mesh (optional)

#   # Flux (GitOps) – example

#   # ───────────────────────────────────────────────────────────────────────────
#   # SECURITY (Portal: Security)
#   # ───────────────────────────────────────────────────────────────────────────

#   # Disk Encryption Set for node OS disks (if required)
#   disk_encryption_set_id = null
#   # API Server security already above (authorized IPs / private cluster)

#   # ───────────────────────────────────────────────────────────────────────────
#   # MAINTENANCE (Portal: Maintenance)
#   # ───────────────────────────────────────────────────────────────────────────

#   # maintenance_window = {
#   #   # Either a "default" or "node_os" schedule can be provided depending on your needs.
#   #   # Example: weekly window on Saturday 22:00–23:30 local:
#   #   allowed = [{
#   #     day   = "Saturday"         # Monday..Sunday
#   #     hours = [22, 23]           # full hours only
#   #   }]
#   #   # Not allowed windows example:
#   #   # not_allowed = [{
#   #   #   start = "2026-01-20T22:00:00Z"
#   #   #   end   = "2026-01-20T23:59:59Z"
#   #   # }]
#   # }

#   # ───────────────────────────────────────────────────────────────────────────
#   # DIAGNOSTICS (Portal: Integration/Logs/Diagnostic settings)
#   # ───────────────────────────────────────────────────────────────────────────

#   # diagnostic_settings = {
#   #   enabled = false
#   #   # name                       = "aks-diag"
#   #   # log_analytics_workspace_id = "<law-id>"
#   #   # eventhub_authorization_rule_id = null
#   #   # eventhub_name                  = null
#   #   # storage_account_id             = null
#   #   # logs                           = [{ category = "kube-apiserver", enabled = true }]
#   #   # metrics                        = [{ category = "AllMetrics", enabled = true }]
#   # }

#   # ───────────────────────────────────────────────────────────────────────────
#   # OUTPUT SHAPING
#   # ───────────────────────────────────────────────────────────────────────────

#   # You can usually control whether to output kubeconfig and sensitive data.
#   # Check module docs for flags like:
#   #   expose_kube_config         = true
#   #   redact_secrets_in_outputs  = true
# }


#note:
#1: dns_prefix_private_cluster required private_dns_zone_id
#2: if local_account_disabled true then role_based_access_control_enabled must be true and it required azure_active_directory_role_based_access_control
#3: api_server_access_profile required then subnet is not allowed to be same with agent node subnet
module "avm-res-containerservice-managedcluster" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.3.3"

  name                       = "dr-aks-02"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  kubernetes_version         = "1.34.1" # optional; omit to use default
  sku_tier                   = "Free"   # "Free" | "Standard" (AKS Uptime SLA)
  enable_telemetry           = false    
  oidc_issuer_enabled        = true
  workload_identity_enabled  = true
  azure_policy_enabled       = true
  #dns_prefix_private_cluster = "dr-aks-02"
  #private_dns_zone_id        = local.private_dns_ids["aks"] 
  dns_prefix = "dr-aks-02"

  local_account_disabled = false
  role_based_access_control_enabled = false #Enabling Azure Active Directory integration requires that `role_based_access_control_enabled` be set to true."
  # azure_active_directory_role_based_access_control = {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   admin_group_object_ids = []  #["<AAD-Group-Object-ID>"]
  #   azure_rbac_enabled = true
  # }

  # Identity
  managed_identities = {
    #type = "UserAssigned"                    # or "UserAssigned" or "SystemAssigned, UserAssigned"
    user_assigned_resource_ids = [module.avm-res-managedidentity-userassignedidentity["aks"].resource_id]
  }

  # Tags (Basics → Tags)
  tags = {
    environment = "dev"
    owner       = "madan"
    costcenter  = "cc-001"
  }

  # API server access (Basics → API server)
  # api_server_access_profile = {
  #   authorized_ip_ranges = [ # Only for Public clusters
  #     # "x.x.x.x/32"
  #   ]
  #   subnet_id                           = data.azurerm_subnet.existing["vnet1_manual:snet1"].id # Required if enable_vnet_integration=true
  #   virtual_network_integration_enabled = true
  # }

  default_node_pool = {
    name            = "systemnp"
    vm_size         = "Standard_DS3_v2"
    os_disk_size_gb = 128
    os_disk_type    = "Managed" # "Managed"|"Ephemeral"
    zones           = ["1", "2", "3"]
    #node_count           = 3
    min_count            = 3 # set both min/max to enable cluster autoscaler
    type                 = "VirtualMachineScaleSets"
    max_count            = 5
    auto_scaling_enabled = true
    max_pods             = 110
    vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
    orchestrator_version = null # inherit cluster version if null
    # Optional
    kubelet_config = {
      cpu_manager_policy        = null
      cpu_cfs_quota_enabled     = null
      cpu_cfs_quota_period      = null
      image_gc_high_threshold   = 85
      image_gc_low_threshold    = 70
      topology_manager_policy   = null
      allowed_unsafe_sysctls    = []
      container_log_max_size_mb = 25
      container_log_max_line    = 5
      # eviction_hard, eviction_soft, etc., can be added if needed
    }
    linux_os_config = {
      swap_file_size_mb = 0
      sysctl_config = {
        net_core_somaxconn           = 16384
        net_ipv4_tcp_tw_reuse        = false
        net_ipv4_ip_local_port_range = "1024 65535"
      }
      transparent_huge_page_defrag = "madvise"
    }
    node_labels = {
      "nodepool-type" = "system"
    }
    node_taints = [] # e.g., ["CriticalAddonsOnly=true:NoSchedule"]
  }

  # Additional user pools (Portal: Node pools → Add node pool)
  node_pools = {
    np1 = {
      name    = "usernp1"
      vm_size = "Standard_D4s_v5"
      mode    = "User"
      #node_count           = 2
      min_count            = 2
      max_count            = 10
      auto_scaling_enabled = true
      vnet_subnet_id       = data.azurerm_subnet.existing["vnet1_manual:snet1"].id
      os_sku               = "Ubuntu"
      os_type              = "Linux"
      os_disk_size_gb      = 128
      os_disk_type         = "Managed"
      max_pods             = 110
      #kubelet_config       = null
      #linux_os_config      = null
      node_labels = {
        "workload" = "apps"
      }
      node_taints          = ["infysvc"]
      zones                = ["1", "2", "3"]
      orchestrator_version = null

    }
  }

  network_profile = {
    network_plugin      = "azure"  # "azure" (CNI) or "kubenet"
    network_policy      = "azure"  # "azure" | "calico" (depends on plugin/region)
    ebpf_data_plane     = "cilium" # "cilium" (preview in some regions) or null
    network_plugin_mode = "overlay"
    dns_service_ip      = "10.2.0.10"
    service_cidr        = "10.2.0.0/24"
    #docker_bridge_cidr= "172.17.0.1/16"
    outbound_type     = "loadBalancer" # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
    load_balancer_sku = "standard"     # "Basic" | "standard"
    pod_cidr          = null           # for kubenet
    pod_cidrs         = null
    service_cidrs     = null
  }
}


# resource "azurerm_role_assignment" "aks_dns" {
#   scope                = local.private_dns_ids["aks"]
#   role_definition_name = "Private DNS Zone Contributor"
#   principal_id         = module.avm-res-managedidentity-userassignedidentity["aks"].principal_id
# }


# variable "wi_namespace" {
#   type        = string
#   default     = "mk"
#   description = "Namespace for ServiceAccount used with Workload Identity"
# }

# variable "wi_service_account" {
#   type        = string
#   default     = "workload-sa"
#   description = "ServiceAccount name used with Workload Identity"
# }
# #kubectl create serviceaccount workload-sa -n mk

# resource "azurerm_federated_identity_credential" "wi_app_fic" {
#   name                = "wi-app-fic"
#   resource_group_name = data.azurerm_resource_group.rg.name
#   parent_id           = module.avm-res-managedidentity-userassignedidentity["wi_app"].resource_id
#   audience            = ["api://AzureADTokenExchange"]

#   issuer  = module.avm-res-containerservice-managedcluster.oidc_issuer_url
#   subject = "system:serviceaccount:${var.wi_namespace}:${var.wi_service_account}"
# }



# # Option A: raw kubeconfig
# provider "kubernetes" {
#   host                   = yamldecode(module.avm-res-containerservice-managedcluster.kube_admin_config).clusters[0].cluster.server
#   client_certificate     = base64decode(yamldecode(module.avm-res-containerservice-managedcluster.kube_admin_config).users[0].user["client-certificate-data"])
#   client_key             = base64decode(yamldecode(module.avm-res-containerservice-managedcluster.kube_admin_config).users[0].user["client-key-data"])
#   cluster_ca_certificate = base64decode(yamldecode(module.avm-res-containerservice-managedcluster.kube_admin_config).clusters[0].cluster["certificate-authority-data"])
# }

# resource "kubernetes_namespace" "wi_ns" {
#   metadata {
#     name = "mk01"
#     labels = {
#       "azure-workload-identity" = "enabled"
#     }
#   }
# }

# resource "kubernetes_service_account" "wi_sa" {
#   metadata {
#     name      = "mk01-sa"
#     namespace = var.wi_namespace
#     annotations = {
#       "azure.workload.identity/client-id" = module.avm-res-managedidentity-userassignedidentity["aks"].client_id
#     }
#     labels = {
#       "azure.workload.identity/use" = "true"
#     }
#   }
#   automount_service_account_token = true
# }

# resource "azurerm_federated_identity_credential" "wi_mk01_fic" {
#   name                = "wi-app-mk01-fic"
#   resource_group_name = data.azurerm_resource_group.rg.name
#   parent_id           = module.avm-res-managedidentity-userassignedidentity["aks"].resource_id
#   audience            = ["api://AzureADTokenExchange"]

#   issuer  = module.avm-res-containerservice-managedcluster.oidc_issuer_url
#   subject = "system:serviceaccount:mk01:mk01-sa"
# }