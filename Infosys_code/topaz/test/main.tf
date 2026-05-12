data "azurerm_resource_group" "rg_aks" {
  name = "rg-aks-isinfytopaz-test"   #contributor
}
 
data "azurerm_resource_group" "rg_vnet" {
  name = "rg-cind-network-test"   #Reader
}
 
data "azurerm_storage_account" "aks_diag_st" {
  name                = "stcinakslogstest"
  resource_group_name = "rg-cind-mgmt"   
}
data "azuread_group" "ad_group" {
display_name   = "ISEPM-AKS-ADMINS"
security_enabled = true             #Directory reader
}
 
 
# Data block to reference an existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "law" {
  name                = "IL-InformationSystems-AKS"
  resource_group_name = "rg-cind-log-analytics"
}
data "azurerm_key_vault" "kv" {
  name                = "kv-cind-aksencrpyt-test"       # Existing Key Vault name
  resource_group_name = "rg-cind-paas-test"      # Resource group where it exists
}
data "azurerm_key_vault_key" "example" {
  name         = "topaz-test"
  key_vault_id = data.azurerm_key_vault.kv.id
}
resource "azurerm_disk_encryption_set" "example" {
  name                = "isinfytopaz-test-set"
  resource_group_name = data.azurerm_resource_group.rg_aks.name
  location            = data.azurerm_resource_group.rg_aks.location
  key_vault_key_id    = data.azurerm_key_vault_key.example.versionless_id
  encryption_type     = "EncryptionAtRestWithCustomerKey"
  auto_key_rotation_enabled = true
  identity {
    type = "SystemAssigned"
  }
}
#--------------------------------------------------------------------
# Virtual Network and Subnet
#--------------------------------------------------------------------
module "avm_res_network_virtualnetwork" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.16.0"
  for_each = { for k, v in local.vnets_to_create : k => v }
  #for_each = local.vnets_to_create
  name      = each.value.name
  location  = each.value.location
  parent_id = each.value.parent_id
  address_space = each.value.address_space
  enable_telemetry = false
  dns_servers      = (try(each.value.dns_servers, null) == null ? null : { dns_servers = each.value.dns_servers })
  # --- Transform your subnet_configs -> module.subnets expected shape ---
  subnets = {
    for sk, s in each.value.subnet_configs : sk => {
      name             = s.name
      address_prefixes = s.address_prefix
      default_outbound_access_enabled = try(s.default_outbound_access_enabled, true)
      service_endpoints_with_location = [
        for svc in try(s.service_endpoints, []) : {
          service = svc
          # locations = [each.value.location] # use only if you want location restriction
        }
      ]
      #network_security_group = try((try(s.nsg_key, null) == null ? null : { id = local.nsg_ids[s.nsg_key] }), null)
      #route_table = try(s.route_table, null)
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
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
data "azurerm_virtual_network" "existing" {
  for_each            = { for k, v in local.vnets_existing : k => v }
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}
data "azurerm_subnet" "existing" {
  for_each             = { for k, v in local.existing_subnets_flat : k => v }
  name                 = each.value.subnet_name
  resource_group_name  = each.value.rg_name
  virtual_network_name = data.azurerm_virtual_network.existing[each.value.vnet_key].name
}

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

# --------------------------------------------------------------------
# AKS
# --------------------------------------------------------------------
# note:
# 1: dns_prefix_private_cluster required private_dns_zone_id
# 2: if local_account_disabled true then role_based_access_control_enabled must be true and it required azure_active_directory_role_based_access_control
# 3: api_server_access_profile required then subnet is not allowed to be same with agent node subnet
module "avm-res-containerservice-managedcluster" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.3.3"
  for_each = { for k, v in local.aks_configs : k => v }
  name                       = each.value.name
  location                   = each.value.location
  resource_group_name        = each.value.resource_group_name
  node_resource_group_name   = try(each.value.node_resource_group_name, null) # if null, module will create one with name "${each.value.name}-node-rg"
  kubernetes_version         = each.value.kubernetes_version # optional; omit to use default
  sku_tier                   = each.value.sku_tier   # "Free" | "Standard" (AKS Uptime SLA)
  enable_telemetry           = false    
  oidc_issuer_enabled        = each.value.oidc_issuer_enabled
  workload_identity_enabled  = each.value.workload_identity_enabled
  azure_policy_enabled       = each.value.azure_policy_enabled
  private_cluster_enabled    = each.value.private_cluster_enabled   # force replacement of the cluster if changed
  dns_prefix_private_cluster = each.value.private_cluster_enabled ? each.value.dns_prefix : null
  private_dns_zone_id        = each.value.private_cluster_enabled ? local.private_dns_ids["aks"] : null
  dns_prefix                 = each.value.private_cluster_enabled ? null : each.value.dns_prefix
  http_application_routing_enabled = try(each.value.http_application_routing_enabled, null)
  node_os_channel_upgrade = try(each.value.node_os_channel_upgrade, null)
  disk_encryption_set_id = try(each.value.disk_encryption_set_id, null)
  local_account_disabled = each.value.local_account_disabled
  role_based_access_control_enabled = each.value.role_based_access_control_enabled #Enabling Azure Active Directory integration requires that `role_based_access_control_enabled` be set to true."
  azure_active_directory_role_based_access_control = (
    try(each.value.azure_active_directory_role_based_access_control, null) == null
    ? null
    : {
        tenant_id = data.azurerm_client_config.current.tenant_id
        admin_group_object_ids = each.value.azure_active_directory_role_based_access_control.admin_group_object_ids
        azure_rbac_enabled = each.value.azure_active_directory_role_based_access_control.azure_rbac_enabled
      }
  )
  network_profile = {
    network_plugin      = each.value.network_profile.network_plugin      # "azure" (CNI) or "kubenet"
    network_policy      = each.value.network_profile.network_policy      # "azure" | "calico" (depends on plugin/region)
    network_data_plane     = each.value.network_profile.network_data_plane     # "cilium" (preview in some regions) or null
    network_plugin_mode = each.value.network_profile.network_plugin_mode # "overlay"
    dns_service_ip      = each.value.network_profile.dns_service_ip
    service_cidr        = each.value.network_profile.service_cidr
    outbound_type     = each.value.network_profile.outbound_type # "loadBalancer" | "userDefinedRouting" | "managedNATGateway" | "userAssignedNATGateway"
    load_balancer_sku = each.value.network_profile.load_balancer_sku     # "Basic" | "standard"
    pod_cidr          = try(each.value.network_profile.pod_cidr, null) # required if network_plugin=kubenet; optional otherwise
    pod_cidrs         = try(each.value.network_profile.pod_cidrs, null) # optional list of pod CIDRs; if specified, must contain pod_cidr value
  }
  default_node_pool = {
    name            = each.value.default_node_pool.name
    vm_size         = each.value.default_node_pool.vm_size
    os_sku          = each.value.default_node_pool.os_sku
    os_disk_size_gb = each.value.default_node_pool.os_disk_size_gb
    os_disk_type    = each.value.default_node_pool.os_disk_type # "Managed"|"Ephemeral"
    zones           = try(each.value.default_node_pool.zones, null)
    min_count            = each.value.default_node_pool.min_count # set both min/max to enable cluster autoscaler
    type                 = each.value.default_node_pool.type  # "VirtualMachineScaleSets" | "AvailabilitySet"
    max_count            = each.value.default_node_pool.max_count
    auto_scaling_enabled = each.value.default_node_pool.auto_scaling_enabled
    max_pods             = each.value.default_node_pool.max_pods
    vnet_subnet_id       = each.value.default_node_pool.vnet_subnet_id
    orchestrator_version = null # inherit cluster version if null
    only_critical_addons_enabled = each.value.default_node_pool.only_critical_addons_enabled # optional, only for AKS versions that support it; forces node_taints=["CriticalAddonsOnly=true:NoSchedule"] and node_labels={"CriticalAddonsOnly"="true"}
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
      zones                = try(np_value.zones, null)
      upgrade_settings = {
        drain_timeout_in_minutes      = 0
        node_soak_duration_in_minutes = 0
        max_surge                     = "10%"
      }
    }
  }
 
  oms_agent = (
    try(each.value.oms_agent, null) == null
    ? null
    : {
        log_analytics_workspace_id = each.value.oms_agent.log_analytics_workspace_id
        msi_auth_for_monitoring_enabled = each.value.oms_agent.msi_auth_for_monitoring_enabled
      }
  )

  managed_identities = {
    user_assigned_resource_ids = toset([
      for id_key in try(each.value.user_assigned_identity_keys, []) :
      module.avm-res-managedidentity-userassignedidentity[id_key].resource_id
    ])
  }
  diagnostic_settings = (
    contains(keys(each.value), "diagnostic_settings") && length(each.value.diagnostic_settings) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
        log_analytics_destination_type = "AzureDiagnostics"
        storage_account_resource_id = try(diag.storage_account_resource_id, null)
      }
    }
    : null
  )
  open_service_mesh_enabled = false
  service_mesh_profile = (
    try(each.value.service_mesh_profile, null) == null
    ? null
    : {
        mode = each.value.service_mesh_profile.mode
        revisions = each.value.service_mesh_profile.revisions
        external_ingress_gateway_enabled = each.value.service_mesh_profile.external_ingress_gateway_enabled
        internal_ingress_gateway_enabled = each.value.service_mesh_profile.internal_ingress_gateway_enabled
     }
  )
  key_vault_secrets_provider = {
    secret_rotation_enabled = true
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

 
  
#--------------------------------------------------------------------
# rbac Role Assignment
#--------------------------------------------------------------------
module "avm-res-authorization-roleassignment" {
  source  = "Azure/avm-res-authorization-roleassignment/azurerm"
  version = "0.3.0"
  role_assignments_azure_resource_manager = {
    user_identity_privatedns_aks = {
      scope                = local.private_dns_ids["aks"]
      role_definition_name = "Contributor"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["aks"].principal_id, null)
    }
    user_identity_aks_law = {
      scope                = data.azurerm_log_analytics_workspace.law.id
      role_definition_name = "Contributor"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["aks"].principal_id, null)
    }
    disk_encryption_system_identity_keyvault = {
      scope                = data.azurerm_key_vault.kv.id
      role_definition_name = "Key Vault Administrator"
      principal_id         = azurerm_disk_encryption_set.example.identity[0].principal_id
    }
    aks_spn_vnet_nc = {
      scope                = local.subnet_ids["vnet_aks.snet_aks"]
      role_definition_name = "Network Contributor"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["aks"].principal_id, null)
    }
  }
  enable_telemetry = false
}
#--------------------------------------------------------------------
# Private DNS zone avm module to create and data block to use existing.
#--------------------------------------------------------------------
module "avm-res-network-privatednszone" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.4.4"
  for_each = {for k, v in local.private_dns_zones : k => v }
  enable_telemetry      = false
  domain_name = each.value.private_dns_zone_name
  parent_id = each.value.parent_id
  virtual_network_links = {
    vnet_link = {
      name                  = "${each.value.private_dns_zone_name}-vnetlink"
      virtual_network_id    = each.value.vnet_id
      registration_enabled  = false
    }
  }
}
#--------------------------------------------------------------------
# Private DNS zone avm module to create and data block to use existing.
#--------------------------------------------------------------------
locals {
  private_dns_zones = {
    aks = {
      create_private_dns_zone = true
      private_dns_zone_name = "privatelink.centralindia.azmk8s.io"
      parent_id = data.azurerm_resource_group.rg_aks.id
      vnet_id               = try(local.vnet_ids["vnet_aks"], null)
    }
  }
  private_dns_ids = merge(
    { for k, m in module.avm-res-network-privatednszone : k => m.resource_id },
    #{ for k, d in data.azurerm_private_dns_zone.existing : k => d.id }
  )
}