

data "azurerm_resource_group" "rg" {
  name = "madan-test"
}
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
data "azurerm_virtual_network" "existing" {
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
#note:
#1: dns_prefix_private_cluster required private_dns_zone_id
#2: if local_account_disabled true then role_based_access_control_enabled must be true and it required azure_active_directory_role_based_access_control
#3: api_server_access_profile required then subnet is not allowed to be same with agent node subnet
module "avm-res-containerservice-managedcluster" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.3.3"
  for_each = { for k, v in local.aks_configs : k => v }

  name                       = each.value.name
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = each.value.resource_group_name
  kubernetes_version         = each.value.kubernetes_version # optional; omit to use default
  sku_tier                   = each.value.sku_tier   # "Free" | "Standard" (AKS Uptime SLA)
  enable_telemetry           = false    
  oidc_issuer_enabled        = each.value.oidc_issuer_enabled
  workload_identity_enabled  = each.value.workload_identity_enabled
  azure_policy_enabled       = each.value.azure_policy_enabled
  #dns_prefix_private_cluster = "dr-aks-03"
  #private_dns_zone_id        = local.private_dns_ids["aks"] 
  dns_prefix = each.value.dns_prefix

  local_account_disabled = each.value.local_account_disabled
  role_based_access_control_enabled = each.value.role_based_access_control_enabled #Enabling Azure Active Directory integration requires that `role_based_access_control_enabled` be set to true."
  # azure_active_directory_role_based_access_control = {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   admin_group_object_ids = []  #["<AAD-Group-Object-ID>"]
  #   azure_rbac_enabled = true
  # }

  network_profile = {
    network_plugin      = each.value.network_profile.network_plugin      # "azure" (CNI) or "kubenet"
    network_policy      = each.value.network_profile.network_policy      # "azure" | "calico" (depends on plugin/region)
    ebpf_data_plane     = each.value.network_profile.ebpf_data_plane     # "cilium" (preview in some regions) or null
    network_plugin_mode = each.value.network_profile.network_plugin_mode # "overlay"
    dns_service_ip      = each.value.network_profile.dns_service_ip
    service_cidr        = each.value.network_profile.service_cidr
    outbound_type     = each.value.network_profile.outbound_type # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
    load_balancer_sku = each.value.network_profile.load_balancer_sku     # "Basic" | "standard"
  }

  default_node_pool = {
    name            = each.value.default_node_pool.name
    vm_size         = each.value.default_node_pool.vm_size
    os_disk_size_gb = each.value.default_node_pool.os_disk_size_gb
    os_disk_type    = each.value.default_node_pool.os_disk_type # "Managed"|"Ephemeral"
    zones           = each.value.default_node_pool.zones
    min_count            = each.value.default_node_pool.min_count # set both min/max to enable cluster autoscaler
    type                 = each.value.default_node_pool.type  # "VirtualMachineScaleSets" | "AvailabilitySet"
    max_count            = each.value.default_node_pool.max_count
    auto_scaling_enabled = each.value.default_node_pool.auto_scaling_enabled
    max_pods             = each.value.default_node_pool.max_pods
    vnet_subnet_id       = each.value.default_node_pool.vnet_subnet_id
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
    node_labels = (
      try(each.value.default_node_pool.node_labels, null) == null
      ? null
      : { for k, v in each.value.default_node_pool.node_labels : k => tostring(v) }
    )
    node_taints = [] # e.g., ["CriticalAddonsOnly=true:NoSchedule"]
  }

  # Additional user pools (Portal: Node pools → Add node pool)
  node_pools = {
    for np_key, np_value in try(each.value.node_pools, {}) : np_key => {
      name    = np_value.name
      vm_size = np_value.vm_size
      mode    = np_value.mode  # "System" | "User"
      min_count            = np_value.min_count
      max_count            = np_value.max_count
      auto_scaling_enabled = np_value.auto_scaling_enabled
      vnet_subnet_id       = np_value.vnet_subnet_id
      os_sku               = np_value.os_sku       # "Ubuntu" | "CBLMariner"
      os_type              = np_value.os_type      # "Linux" | "Windows"
      os_disk_size_gb      = np_value.os_disk_size_gb
      os_disk_type         = np_value.os_disk_type # "Managed" | "Ephemeral"
      max_pods             = np_value.max_pods
      node_labels = (
        try(np_value.node_labels, null) == null
        ? null
        : { for k, v in np_value.node_labels : k => tostring(v) }
      )
      node_taints          = try(np_value.node_taints, [])
      zones                = np_value.zones
    }
  }

  managed_identities = {
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }

  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )

  # API server access (Basics → API server)
  # api_server_access_profile = {
  #   authorized_ip_ranges = [ # Only for Public clusters
  #     # "x.x.x.x/32"
  #   ]
  #   subnet_id                           = data.azurerm_subnet.existing["vnet1_manual:snet1"].id # Required if enable_vnet_integration=true
  #   virtual_network_integration_enabled = true
  # }
}




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

resource "azurerm_federated_identity_credential" "wi_app_fic" {
  name                = "wi-app-fic"
  resource_group_name = data.azurerm_resource_group.rg.name
  parent_id           = module.avm-res-managedidentity-userassignedidentity["aks"].resource_id
  audience            = ["api://AzureADTokenExchange"]

  issuer  = module.avm-res-containerservice-managedcluster["dr_aks"].oidc_issuer_url
  subject = "system:serviceaccount:${var.wi_namespace}:${var.wi_service_account}"
}