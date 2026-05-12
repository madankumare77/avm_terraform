data "azurerm_resource_group" "rg_aks" {
  name = "rg-cind-bcms-prod"   #Contributor access and RBAC administrator
}
data "azurerm_resource_group" "rg_vnet" {
  name = "rg-cind-network-prod"   #Reader
}
 
data "azurerm_resource_group" "rg_vnet_paas" {
  name = "rg-cind-network-terraform-prod"
}   #Reader
 
data "azurerm_resource_group" "rg_paas" {
  name = "rg-cind-terraform-paas-prod"
}     #contributor
data "azurerm_storage_account" "aks_diag_st" {
  name                = "stcindakslogsprod" # EPM blob write, storage account key opreator service
  resource_group_name = "rg-cind-paas-prod"    # Reader
}
 
data "azuread_group" "ad_group" {
display_name   = "ISEPM-AKS-ADMINS"
security_enabled = true             #Directory reader
}

# Data block to reference an existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "law" {
  name                = "IL-InformationSystems-AKS-Prod" # rbac administrator, Log Analytics Contributor()
  resource_group_name = "rg-cind-log-analytics"  #Reader
}
 
data "azurerm_log_analytics_workspace" "law_akv" {
  name                = "IL-cind-law-Keyvault-prod" # rbac administrator, Log Analytics Contributor()
  resource_group_name = "rg-cind-mgmt"  #Reader
}
 
data "azurerm_log_analytics_workspace" "law_storage_account" {
  name                = "IL-cind-storage-prod" # rbac administrator, Log Analytics Contributor()
  resource_group_name = "rg-cind-mgmt"  #Reader
}
 
data "azurerm_log_analytics_workspace" "law_function_app" {
  name                = "il-cind-paas-logs-mgmt" # rbac administrator, Log Analytics Contributor()
  resource_group_name = "rg-cind-mgmt"  #Reader
}
 
data "azurerm_key_vault" "kv" {
  name                = "kv-cind-aksencrypt-prod"       # "rbac administrator,Key Vault Crypto Service Encryption User"
  resource_group_name = "rg-cind-paas-prod"      # Resource group where it exists
}
data "azurerm_key_vault_key" "kv_key" {
  name         = "isaksbcmsprod-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}
 
resource "azurerm_disk_encryption_set" "example" {
  name                = "isaksbcmsprod-set"
  resource_group_name = data.azurerm_resource_group.rg_aks.name
  location            = data.azurerm_resource_group.rg_aks.location
  key_vault_key_id    = data.azurerm_key_vault_key.kv_key.versionless_id
  encryption_type = "EncryptionAtRestWithCustomerKey"
  auto_key_rotation_enabled = true

  identity {
    type = "SystemAssigned"
  }
}
# module "avm-res-compute-diskencryptionset" {
#   source  = "Azure/avm-res-compute-diskencryptionset/azurerm"
#   version = "0.1.0"
#   for_each = { for k, v in local.disk_encryption_sets : k => v }
#   name                = each.value.name
#   location            = each.value.location
#   resource_group_name = each.value.resource_group_name
#   key_vault_key_id    = try(each.value.key_vault_key_id, null)
#   key_vault_resource_id = try(each.value.key_vault_resource_id, null)
#   auto_key_rotation_enabled = try(each.value.auto_key_rotation_enabled, null)
#   encryption_type = try(each.value.encryption_type, null)
#   enable_telemetry = false
#   tags = (
#     try(each.value.tags, null) == null
#     ? null
#     : { for k, v in each.value.tags : k => tostring(v) }
#   )
# }
 
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
    secret_rotation_enabled = false
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
      role_definition_name = "Key Vault Contributor" #"Key Vault Administrator"
      principal_id         = azurerm_disk_encryption_set.example.identity[0].principal_id
    }
    des_identity_akv = {
      scope                = data.azurerm_key_vault.kv.id
      role_definition_name = "Key Vault Crypto Service Encryption User" 
      principal_id         = azurerm_disk_encryption_set.example.identity[0].principal_id
    }
    aks_spn_vnet_nc = {
      scope                = local.subnet_ids["vnet_aks.snet_aks"]
      role_definition_name = "Network Contributor"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["aks"].principal_id, null)
    }
    disk_encryption_aks_identity= {
      scope                = azurerm_disk_encryption_set.example.id #azurerm_disk_encryption_set.example.id
      role_definition_name = "Contributor"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["aks"].principal_id, null)
    }
    user_identity_function_stoage = {
      scope                = try(module.avm-res-storage-storageaccount["st_paas"].resource_id, null)
      role_definition_name = "EPM Storage blob writer"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["function"].principal_id, null)
    }
    crypto_function_akv = {
      scope                = try(module.keyvault["kv"].resource_id, null)
      role_definition_name = "Key Vault Crypto User"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["function"].principal_id, null)
    }
    secret_function_akv = {
      scope                = try(module.keyvault["kv"].resource_id, null)
      role_definition_name = "Key Vault Secrets User"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["function"].principal_id, null)
    }
    certificate_function_akv = {
      scope                = try(module.keyvault["kv"].resource_id, null)
      role_definition_name = "Key Vault Certificate User"
      principal_id         = try(module.avm-res-managedidentity-userassignedidentity["function"].principal_id, null)
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
#Key Vault
#--------------------------------------------------------------------
module "keyvault" {
  source   = "Azure/avm-res-keyvault-vault/azurerm"
  version  = "0.10.2"
  for_each = { for k, v in local.keyvault_configs : k => v }
 
  name                            = each.value.name
  location                        = each.value.location
  resource_group_name             = each.value.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = each.value.sku_name
  soft_delete_retention_days      = each.value.soft_delete_retention_days
  purge_protection_enabled        = each.value.purge_protection_enabled
  legacy_access_policies_enabled  = each.value.legacy_access_policies_enabled
  enabled_for_deployment          = each.value.enabled_for_deployment
  enabled_for_disk_encryption     = each.value.enabled_for_disk_encryption
  enabled_for_template_deployment = each.value.enabled_for_template_deployment
  public_network_access_enabled   = each.value.public_network_access_enabled
  enable_telemetry                = false
  # ---- network ACLs: convert vnet/subnet refs -> subnet IDs ----
  network_acls = merge(
    try(each.value.network_acls, {}),
    {
      virtual_network_subnet_ids = [
        for r in try(each.value.network_acls.virtual_network_subnet_refs, []) :
        local.subnet_ids["${r.vnet_key}.${r.subnet_key}"]
      ]
    }
  )
  # ---- private endpoints: derive subnet_resource_id from vnet1.snet1 etc ----
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }
 
  diagnostic_settings = (
    contains(keys(each.value), "diagnostic_settings") && length(each.value.diagnostic_settings) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
      }
    }
    : null
  )
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
 
#--------------------------------------------------------------------
# Function App
#--------------------------------------------------------------------
module "avm-res-web-site" {
  source                                         = "Azure/avm-res-web-site/azurerm"
  for_each                                       = { for k, v in local.function_app_configs : k => v }
  version                                        = "0.19.1"
  name                                           = each.value.name
  location                                       = each.value.location
  resource_group_name                            = each.value.resource_group_name
  kind                                           = each.value.kind
  os_type                                        = each.value.os_type
  https_only                                     = each.value.https_only
  service_plan_resource_id                       = each.value.service_plan_resource_id #module.avm-res-web-serverfarm.resource_id
  storage_account_name                           = each.value.storage_account_name     #module.avm-res-storage-storageaccount["st1"].name
  public_network_access_enabled                  = each.value.public_network_access_enabled
  enable_application_insights                    = each.value.enable_application_insights
  virtual_network_subnet_id                      = each.value.virtual_network_subnet_id
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = each.value.webdeploy_publish_basic_authentication_enabled
  enable_telemetry                               = each.value.enable_telemetry
  app_settings = (
    try(each.value.app_settings, null) == null
    ? null
    : { for k, v in each.value.app_settings : k => tostring(v) }
  )
  site_config = {
    always_on         = try(each.value.site_config.always_on, null)
    application_stack = try(each.value.site_config.application_stack, null)
 
    # application_insights_connection_string = (
    #   each.value.enable_application_insights == true
    #   ? module.avm-res-insights-component[each.value.site_config.app_insights_key].connection_string
    #   : null
    # )
 
    # application_insights_key = (
    #   each.value.enable_application_insights == true
    #   ? module.avm-res-insights-component[each.value.site_config.app_insights_key].instrumentation_key
    #   : null
    # )
  }
 
  diagnostic_settings = (
    contains(keys(each.value), "diagnostic_settings") && length(each.value.diagnostic_settings) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
      }
    }
    : null
  )
 
   # ---- private endpoints: derive subnet_resource_id from vnet1.snet1 etc ----
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
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
  depends_on = [module.avm-res-storage-storageaccount, module.avm-res-web-serverfarm, module.avm-res-authorization-roleassignment]
}
 
#--------------------------------------------------------------------
# App Service Plan
#--------------------------------------------------------------------
module "avm-res-web-serverfarm" {
  source              = "Azure/avm-res-web-serverfarm/azurerm"
  version             = "1.0.0"
  for_each            = { for k, v in local.app_service_plan : k => v }
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  sku_name            = each.value.sku_name
  os_type             = each.value.os_type
  # maximum_elastic_worker_count = each.value.maximum_elastic_worker_count
  zone_balancing_enabled = each.value.zone_balancing_enabled
  enable_telemetry    = false
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
}
 
#--------------------------------------------------------------------
# #Storage Account
#--------------------------------------------------------------------
module "avm-res-storage-storageaccount" {
  source                            = "Azure/avm-res-storage-storageaccount/azurerm"
  for_each                          = { for k, v in local.storage_account_configs : k => v }
  version                           = "0.6.7"
  account_replication_type          = each.value.account_replication_type
  account_tier                      = each.value.account_tier
  location                          = each.value.location
  name                              = each.value.name
  resource_group_name               = each.value.resource_group_name
  access_tier                       = each.value.access_tier
  account_kind                      = each.value.account_kind
  allow_nested_items_to_be_public   = each.value.allow_nested_items_to_be_public
  default_to_oauth_authentication   = each.value.default_to_oauth_authentication
  https_traffic_only_enabled        = each.value.https_traffic_only_enabled
  infrastructure_encryption_enabled = each.value.infrastructure_encryption_enabled
  enable_telemetry                  = each.value.enable_telemetry
  local_user_enabled                = each.value.local_user_enabled
  min_tls_version                   = each.value.min_tls_version
  public_network_access_enabled     = each.value.public_network_access_enabled
  sftp_enabled                      = each.value.sftp_enabled
  shared_access_key_enabled         = each.value.shared_access_key_enabled
  network_rules = (
    length(try(each.value.network_rules_subnet_refs, [])) == 0
    ? null
    : {
      # optional - you can add default_action/bypass here if your module expects it
      virtual_network_subnet_ids = [
        for r in each.value.network_rules_subnet_refs :
        local.subnet_ids["${r.vnet_key}.${r.subnet_key}"]
      ]
    }
  )
 
  private_endpoints = {
    for pe_key, pe in try(each.value.private_endpoints, {}) : pe_key => {
      name                          = try(pe.name, null)
      subnet_resource_id            = local.subnet_ids["${pe.vnet_key}.${pe.subnet_key}"]
      subresource_name              = pe.subresource_name
      private_dns_zone_resource_ids = try(pe.private_dns_zone_resource_ids, [])
      tags                          = try(pe.tags, null)
    }
  }
  blob_properties = (
    try(each.value.blob_properties, null) == null
    ? null
    : {
      change_feed_enabled           = try(each.value.blob_properties.change_feed_enabled, null)
      change_feed_retention_in_days = try(each.value.blob_properties.change_feed_retention_in_days, null)
      default_service_version       = try(each.value.blob_properties.default_service_version, null)
      last_access_time_enabled      = try(each.value.blob_properties.last_access_time_enabled, null)
      versioning_enabled            = try(each.value.blob_properties.versioning_enabled, null)
 
      delete_retention_policy = (try(each.value.blob_properties.delete_retention_policy, null) == null ? null : {
        days = each.value.blob_properties.delete_retention_policy.days
        permanent_delete_enabled = each.value.blob_properties.delete_retention_policy.permanent_delete_enabled
      })
      container_delete_retention_policy = (try(each.value.blob_properties.container_delete_retention_policy, null) == null ? null : {
        days = each.value.blob_properties.container_delete_retention_policy.days
        #enabled = each.value.blob_properties.container_delete_retention_policy.enabled
      })
    }
  )
 
  immutability_policy = (
    try(each.value.immutability_policy, null) == null
    ? null
    : {
      state         = each.value.immutability_policy.state
      period_since_creation_in_days = each.value.immutability_policy.period_since_creation_in_days
      allow_protected_append_writes = each.value.immutability_policy.allow_protected_append_writes
    }
  )
 
  diagnostic_settings_blob = (
    contains(keys(each.value), "diagnostic_settings_blob") && length(each.value.diagnostic_settings_blob) > 0
    ? {
      for diag_k, diag in each.value.diagnostic_settings_blob :
      diag_k => {
        name                  = try(diag.name, null)
        workspace_resource_id = try(diag.workspace_resource_id, null)
        metric_categories     = try(toset(diag.metric_categories), null)
      }
    }
    : null
  )
  tags = (
    try(each.value.tags, null) == null
    ? null
    : { for k, v in each.value.tags : k => tostring(v) }
  )
 
}