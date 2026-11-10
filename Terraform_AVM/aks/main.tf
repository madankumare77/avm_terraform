####AKS####
data "azurerm_resource_group" "rg" {
  name = "rg-infy-terraform"
}

module "vnet_aks" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.16.0"
  name = "vnet-aks"
  address_space          = ["10.2.0.0/16"]
  location = data.azurerm_resource_group.rg.location
  parent_id = data.azurerm_resource_group.rg.id
  enable_telemetry = false
  subnets = {
    "snet_aks" = {
      name             = "snet_aks"
      address_prefixes = ["10.2.0.0/24"]
    }
  }
}


#--------------------------------------------------------------------
# #AKS configurations
#--------------------------------------------------------------------
locals {
  aks_configs = {
    aks_without = {
      name = "aks-app-addon"
      resource_group_name = data.azurerm_resource_group.rg.name
      location = data.azurerm_resource_group.rg.location
      sku_tier                   = "Free"
      oidc_issuer_enabled        = true
      workload_identity_enabled  = true
      azure_policy_enabled       = true
      dns_prefix = "aks-app-addon"
      local_account_disabled = false
      private_cluster_enabled    = false                    # force replacement of the cluster if changed
      role_based_access_control_enabled = false                      # force replacement of the cluster if changed
      azure_policy_enabled = true
      # azure_active_directory_role_based_access_control = {
      #   tenant_id = data.azurerm_client_config.current.tenant_id
      #   admin_group_object_ids = try([data.azuread_group.ad_group.object_id], null)
      #   azure_rbac_enabled = false                        # (false uses Microsoft entra ID authentication with kubernetes RBAC)
      # }
      managed_identities = {
        system_assigned = true
      }
      default_node_pool = {
        name            = "systemnp"
        vm_size         = "Standard_D4ds_v5"
        os_disk_size_gb = 128
        os_disk_type    = "Managed"
        zones           = ["1"]   #["1", "2", "3"]
        min_count            = 3
        type                 = "VirtualMachineScaleSets"
        max_count            = 5
        auto_scaling_enabled = true
        max_pods             = 110
        vnet_subnet_id       = module.vnet_aks.subnets["snet_aks"].resource_id
        # node_labels = {
        #   "nodepool-type" = "system"
        # }
        node_taints          = ["CriticalAddonsOnly=true:NoSchedule"]
      }
      #node_resource_group_name = "rg-node4-terraform-aks-cind"    #data.azurerm_resource_group.rg_dr.name   #
      network_profile = {
        network_plugin      = "azure" 
        network_policy      = "cilium" 
        network_data_plane  = "cilium"
        network_plugin_mode = "overlay"
        dns_service_ip      = "10.3.0.10"
        service_cidr        = "10.3.0.0/24"
        outbound_type     = "loadBalancer"
        load_balancer_sku = "standard"
      }
    #   service_mesh_profile = {
    #     mode = "Istio"
    #     revisions = ["asm-1-27"]
    #     external_ingress_gateway_enabled = true
    #     internal_ingress_gateway_enabled = true
    #   }
      # diagnostic_settings = {
      #   di_diag = {
      #     name                  = "diag-aks-dr-001cd"
      #     workspace_resource_id = try(module.law.resource_id, null)
      #   }
      # }
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }

    }
  }
}


module "avm-res-containerservice-managedcluster" {
  source   = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version  = "0.3.3"
  for_each = { for k, v in local.aks_configs : k => v }

  name                      = each.value.name
  location                  = data.azurerm_resource_group.rg.location
  resource_group_name       = each.value.resource_group_name
  kubernetes_version        = try(each.value.kubernetes_version, null) # optional; omit to use default
  sku_tier                  = each.value.sku_tier           # "Free" | "Standard" (AKS Uptime SLA)
  enable_telemetry          = false
  oidc_issuer_enabled       = each.value.oidc_issuer_enabled
  workload_identity_enabled = each.value.workload_identity_enabled
  azure_policy_enabled      = each.value.azure_policy_enabled

  private_cluster_enabled = each.value.private_cluster_enabled # force replacement of the cluster if changed
  #dns_prefix_private_cluster = "dr-aks-03"
  #private_dns_zone_id        = local.private_dns_ids["aks"] 
  dns_prefix = each.value.dns_prefix

  local_account_disabled            = each.value.local_account_disabled
  role_based_access_control_enabled = each.value.role_based_access_control_enabled #Enabling Azure Active Directory integration requires that `role_based_access_control_enabled` be set to true."

  azure_active_directory_role_based_access_control = (
    try(each.value.azure_active_directory_role_based_access_control, null) == null
    ? null
    : {
      tenant_id              = data.azurerm_client_config.current.tenant_id
      admin_group_object_ids = each.value.azure_active_directory_role_based_access_control.admin_group_object_ids
      azure_rbac_enabled     = each.value.azure_active_directory_role_based_access_control.azure_rbac_enabled
    }
  )


  network_profile = {
    network_plugin      = each.value.network_profile.network_plugin      # "azure" (CNI) or "kubenet"
    network_policy      = each.value.network_profile.network_policy      # "azure" | "calico" (depends on plugin/region)
    network_data_plane  = each.value.network_profile.network_data_plane  # "cilium" (preview in some regions) or null
    network_plugin_mode = each.value.network_profile.network_plugin_mode # "overlay"
    dns_service_ip      = each.value.network_profile.dns_service_ip
    service_cidr        = each.value.network_profile.service_cidr
    outbound_type       = each.value.network_profile.outbound_type     # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
    load_balancer_sku   = each.value.network_profile.load_balancer_sku # "Basic" | "standard"
  }

  default_node_pool = {
    name                 = each.value.default_node_pool.name
    vm_size              = each.value.default_node_pool.vm_size
    os_disk_size_gb      = each.value.default_node_pool.os_disk_size_gb
    os_disk_type         = each.value.default_node_pool.os_disk_type # "Managed"|"Ephemeral"
    zones                = try(each.value.default_node_pool.zones, null)
    min_count            = each.value.default_node_pool.min_count # set both min/max to enable cluster autoscaler
    type                 = each.value.default_node_pool.type      # "VirtualMachineScaleSets" | "AvailabilitySet"
    max_count            = each.value.default_node_pool.max_count
    auto_scaling_enabled = each.value.default_node_pool.auto_scaling_enabled
    max_pods             = each.value.default_node_pool.max_pods
    vnet_subnet_id       = each.value.default_node_pool.vnet_subnet_id
    orchestrator_version = try(each.value.default_node_pool.orchestrator_version, null) # inherit cluster version if null
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
    upgrade_settings = {
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
      max_surge                     = "10%"
    }
    node_labels = (
      try(each.value.default_node_pool.node_labels, null) == null
      ? null
      : { for k, v in each.value.default_node_pool.node_labels : k => tostring(v) }
    )
    node_taints = try(each.value.default_node_pool.node_taints, []) # e.g., ["CriticalAddonsOnly=true:NoSchedule"]
  }

  # Additional user pools (Portal: Node pools → Add node pool)
  node_resource_group_name = try(each.value.node_resource_group_name, null) # if not specified, node RG will be named MC_<RG>_<clusterName>_<location>
  node_pools = {
    for np_key, np_value in try(each.value.node_pools, {}) : np_key => {
      name                 = np_value.name
      vm_size              = np_value.vm_size
      mode                 = np_value.mode # "System" | "User"
      min_count            = np_value.min_count
      max_count            = np_value.max_count
      auto_scaling_enabled = np_value.auto_scaling_enabled
      vnet_subnet_id       = np_value.vnet_subnet_id
      os_sku               = np_value.os_sku  # "Ubuntu" | "CBLMariner"
      os_type              = np_value.os_type # "Linux" | "Windows"
      os_disk_size_gb      = np_value.os_disk_size_gb
      os_disk_type         = np_value.os_disk_type # "Managed" | "Ephemeral"
      max_pods             = np_value.max_pods
      orchestrator_version = try(np_value.orchestrator_version, null) # inherit cluster version if null
      node_labels = (
        try(np_value.node_labels, null) == null
        ? null
        : { for k, v in np_value.node_labels : k => tostring(v) }
      )
      node_taints = try(np_value.node_taints, [])
      zones       = try(np_value.zones, null)
      upgrade_settings = {
        drain_timeout_in_minutes      = 0
        node_soak_duration_in_minutes = 0
        max_surge                     = "10%"
      }
    }
  }

  upgrade_override = {
    force_upgrade_enabled = false
    effective_until      = "2099-12-31T23:59:59Z"
  }

  managed_identities = {
    system_assigned = try(each.value.managed_identities.system_assigned, false)
  }

  diagnostic_settings = (
    contains(keys(each.value), "diagnostic_settings") && length(each.value.diagnostic_settings) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings :
      diag_k => {
        name                           = try(diag.name, null)
        workspace_resource_id          = try(diag.workspace_resource_id, null)
        log_analytics_destination_type = "AzureDiagnostics"
      }
    }
    : null
  )
  open_service_mesh_enabled = false
  service_mesh_profile = (
    try(each.value.service_mesh_profile, null) == null
    ? null
    : {
      mode                             = each.value.service_mesh_profile.mode
      revisions                        = each.value.service_mesh_profile.revisions
      external_ingress_gateway_enabled = each.value.service_mesh_profile.external_ingress_gateway_enabled
      internal_ingress_gateway_enabled = each.value.service_mesh_profile.internal_ingress_gateway_enabled
    }
  )

  lock = (
    try(each.value.lock, null) == null
    ? null
    : {
      kind = each.value.lock.kind
      name = each.value.lock.name
    }
  )

  key_vault_secrets_provider = {
    secret_rotation_enabled = false
  }

  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}

resource "azapi_update_resource" "gateway_api_app_routing" {
  type = "Microsoft.ContainerService/managedClusters@2026-03-01"
  resource_id = module.avm-res-containerservice-managedcluster["aks_without"].resource_id
  body = {
    properties = {
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }

        webAppRouting = {
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
    }
  }

  response_export_values = [
    "properties.ingressProfile"
  ]

  depends_on = [
    module.avm-res-containerservice-managedcluster
  ]
}

## Resource Policy Contributor role required to assign policy to resource group
data "azurerm_policy_set_definition" "aks_pod_security_baseline" {
  display_name = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
}
resource "azurerm_resource_group_policy_assignment" "aks_pod_security_baseline" {
  name = "aks-pod-security-baseline"
  display_name = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
  resource_group_id = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_set_definition.aks_pod_security_baseline.id
  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Kubernetes cluster should not allow privileged containers
# Kubernetes clusters should not allow container privilege escalation
# Kubernetes cluster containers should not share host namespaces
# Kubernetes cluster pods should only use approved host network and port list
# Kubernetes cluster containers should only use allowed capabilities
# Kubernetes clusters should not grant CAP_SYS_ADMIN security capabilities
# Kubernetes cluster containers should run with a read only root file system
# Kubernetes cluster pods and containers should only run with approved user and group IDs
# Kubernetes cluster pods should only use allowed volume types
# Kubernetes cluster pod hostPath volumes should only use allowed host paths
# Kubernetes clusters should be accessible only over HTTPS
# Kubernetes clusters should use internal load balancers
# Ensure cluster containers have readiness or liveness probes configured
# Kubernetes cluster containers CPU and memory resource requests must be defined
# Kubernetes cluster container images should not include latest image tag
# Kubernetes clusters should disable automounting API credentials
# Kubernetes clusters should not use the default namespace
# Kubernetes cluster services should use unique selectors
# Kubernetes clusters should specify host in ingress resource rules
# Kubernetes cluster should not use naked pods


#01
data "azurerm_policy_definition" "no_privileged_containers" {
  display_name = "Kubernetes cluster should not allow privileged containers"
}

resource "azurerm_resource_group_policy_assignment" "no_privileged_containers" {
  name                 = "aks-no-privileged"
  display_name         = "AKS - Do not allow privileged containers"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_privileged_containers.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#02
data "azurerm_policy_definition" "no_privilege_escalation" {
  display_name = "Kubernetes clusters should not allow container privilege escalation"
}

resource "azurerm_resource_group_policy_assignment" "no_privilege_escalation" {
  name                 = "aks-no-priv-escalation"
  display_name         = "AKS - Do not allow privilege escalation"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_privilege_escalation.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#03
data "azurerm_policy_definition" "no_host_namespaces" {
  display_name = "Kubernetes cluster containers should not share host namespaces"
}

resource "azurerm_resource_group_policy_assignment" "no_host_namespaces" {
  name                 = "aks-no-host-namespace"
  display_name         = "AKS - Do not share host namespaces"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_host_namespaces.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#04
data "azurerm_policy_definition" "host_network_ports" {
  display_name = "Kubernetes cluster pods should only use approved host network and port list"
}

resource "azurerm_resource_group_policy_assignment" "host_network_ports" {
  name                 = "aks-host-network-ports"
  display_name         = "AKS - Approved host network and ports"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.host_network_ports.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#05
data "azurerm_policy_definition" "allowed_capabilities" {
  display_name = "Kubernetes cluster containers should only use allowed capabilities"
}

resource "azurerm_resource_group_policy_assignment" "allowed_capabilities" {
  name                 = "aks-allowed-capabilities"
  display_name         = "AKS - Allowed container capabilities"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.allowed_capabilities.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#06
data "azurerm_policy_definition" "no_sys_admin" {
  display_name = "Kubernetes clusters should not grant CAP_SYS_ADMIN security capabilities"
}

resource "azurerm_resource_group_policy_assignment" "no_sys_admin" {
  name                 = "aks-no-sys-admin"
  display_name         = "AKS - Block CAP_SYS_ADMIN"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_sys_admin.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#07
data "azurerm_policy_definition" "readonly_root_filesystem" {
  display_name = "Kubernetes cluster containers should run with a read only root file system"
}

resource "azurerm_resource_group_policy_assignment" "readonly_root_filesystem" {
  name                 = "aks-readonly-rootfs"
  display_name         = "AKS - Read-only root filesystem"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.readonly_root_filesystem.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#08
data "azurerm_policy_definition" "approved_users_groups" {
  display_name = "Kubernetes cluster pods and containers should only run with approved user and group IDs"
}

resource "azurerm_resource_group_policy_assignment" "approved_users_groups" {
  name                 = "aks-approved-users"
  display_name         = "AKS - Approved users and groups"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.approved_users_groups.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#09
data "azurerm_policy_definition" "allowed_volume_types" {
  display_name = "Kubernetes cluster pods should only use allowed volume types"
}

resource "azurerm_resource_group_policy_assignment" "allowed_volume_types" {
  name                 = "aks-allowed-volumes"
  display_name         = "AKS - Allowed volume types"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.allowed_volume_types.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#10
data "azurerm_policy_definition" "allowed_host_paths" {
  display_name = "Kubernetes cluster pod hostPath volumes should only use allowed host paths"
}

resource "azurerm_resource_group_policy_assignment" "allowed_host_paths" {
  name                 = "aks-allowed-hostpaths"
  display_name         = "AKS - Allowed host paths"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.allowed_host_paths.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#11
data "azurerm_policy_definition" "https_ingress" {
  display_name = "Kubernetes clusters should be accessible only over HTTPS"
}

resource "azurerm_resource_group_policy_assignment" "https_ingress" {
  name                 = "aks-https-ingress"
  display_name         = "AKS - Require HTTPS ingress"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.https_ingress.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#12
data "azurerm_policy_definition" "internal_load_balancer" {
  display_name = "Kubernetes clusters should use internal load balancers"
}

resource "azurerm_resource_group_policy_assignment" "internal_load_balancer" {
  name                 = "aks-internal-lb"
  display_name         = "AKS - Internal load balancers"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.internal_load_balancer.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#13
data "azurerm_policy_definition" "required_probes" {
  display_name = "Ensure cluster containers have readiness or liveness probes configured"
}

resource "azurerm_resource_group_policy_assignment" "required_probes" {
  name                 = "aks-required-probes"
  display_name         = "AKS - Require readiness or liveness probes"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.required_probes.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#14
data "azurerm_policy_definition" "resource_requests" {
  display_name = "Kubernetes cluster containers CPU and memory resource requests must be defined"
}

resource "azurerm_resource_group_policy_assignment" "resource_requests" {
  name                 = "aks-resource-requests"
  display_name         = "AKS - Require CPU and memory requests"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.resource_requests.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#15
data "azurerm_policy_definition" "no_latest_tag" {
  display_name = "Kubernetes cluster container images should not include latest image tag"
}

resource "azurerm_resource_group_policy_assignment" "no_latest_tag" {
  name                 = "aks-no-latest-tag"
  display_name         = "AKS - Do not use latest image tag"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_latest_tag.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#16
data "azurerm_policy_definition" "disable_automount" {
  display_name = "Kubernetes clusters should disable automounting API credentials"
}

resource "azurerm_resource_group_policy_assignment" "disable_automount" {
  name                 = "aks-disable-automount"
  display_name         = "AKS - Disable API credential automount"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.disable_automount.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#17
data "azurerm_policy_definition" "no_default_namespace" {
  display_name = "Kubernetes clusters should not use the default namespace"
}

resource "azurerm_resource_group_policy_assignment" "no_default_namespace" {
  name                 = "aks-no-default-ns"
  display_name         = "AKS - Do not use default namespace"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.no_default_namespace.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#18
data "azurerm_policy_definition" "unique_service_selectors" {
  display_name = "Kubernetes cluster services should use unique selectors"
}

resource "azurerm_resource_group_policy_assignment" "unique_service_selectors" {
  name                 = "aks-unique-selectors"
  display_name         = "AKS - Unique service selectors"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.unique_service_selectors.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#19
data "azurerm_policy_definition" "require_ingress_host" {
  display_name = "Kubernetes clusters should specify host in ingress resource rules"
}

resource "azurerm_resource_group_policy_assignment" "require_ingress_host" {
  name                 = "aks-require-ing-host"
  display_name         = "AKS - Require ingress host"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.require_ingress_host.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
#20
data "azurerm_policy_definition" "block_naked_pods" {
  display_name = "Kubernetes cluster should not use naked pods"
}

resource "azurerm_resource_group_policy_assignment" "block_naked_pods" {
  name                 = "aks-block-naked-pods"
  display_name         = "AKS - Block naked pods"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.block_naked_pods.id
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
########################