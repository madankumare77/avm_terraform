resource "azurerm_mssql_managed_instance" "this" {
  license_type                   = var.license_type
  location                       = var.location
  name                           = var.name
  resource_group_name            = var.resource_group_name
  sku_name                       = var.sku_name
  storage_size_in_gb             = var.storage_size_in_gb
  subnet_id                      = var.subnet_id
  vcores                         = var.vcores
  database_format                = var.database_format
  administrator_login            = var.administrator_login
  administrator_login_password   = var.administrator_login_password
  collation                      = var.collation
  dns_zone_partner_id            = var.dns_zone_partner_id
  maintenance_configuration_name = var.maintenance_configuration_name
  minimum_tls_version            = var.minimum_tls_version
  proxy_override                 = var.proxy_override
  public_data_endpoint_enabled   = var.public_data_endpoint_enabled
  storage_account_type           = var.storage_account_type
  tags                           = var.tags
  timezone_id                    = var.timezone_id
  zone_redundant_enabled         = var.zone_redundant_enabled

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # identity is done via an azapi_resource_action further on, because of this bug that
  # prevents system & user assigned identities being set at the same time.
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/19802
  lifecycle {
    ignore_changes = [
      identity,
      database_format
    ]
  }
}

resource "azurerm_mssql_managed_instance_active_directory_administrator" "this" {
  count = try(var.active_directory_administrator.object_id, null) == null ? 0 : 1

  login_username              = var.active_directory_administrator.login_username
  managed_instance_id         = azurerm_mssql_managed_instance.this.id
  object_id                   = var.active_directory_administrator.object_id
  tenant_id                   = var.active_directory_administrator.tenant_id
  azuread_authentication_only = var.active_directory_administrator.azuread_authentication_only

  dynamic "timeouts" {
    for_each = var.active_directory_administrator.timeouts == null ? [] : [var.active_directory_administrator.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# https://learn.microsoft.com/en-us/rest/api/sql/managed-server-security-alert-policies/create-or-update?view=rest-sql-2023-08-01-preview&tabs=HTTP
resource "azapi_resource_action" "mssql_managed_instance_security_alert_policy" {
  count = var.security_alert_policy == {} ? 0 : 1

  method      = "PUT"
  resource_id = "${azurerm_mssql_managed_instance.this.id}/securityAlertPolicies/Default"
  type        = "Microsoft.Sql/managedInstances/securityAlertPolicies@2023-08-01-preview"
  body = {
    properties = {
      disabledAlerts          = try(var.security_alert_policy.disabled_alerts, [])
      emailAccountAdmins      = try(var.security_alert_policy.email_account_admins_enabled, false)
      emailAddresses          = try(var.security_alert_policy.email_addresses, [])
      retentionDays           = try(var.security_alert_policy.retention_days, 0)
      state                   = try(var.security_alert_policy.enabled ? "Enabled" : "Disabled", "Enabled")
      storageAccountAccessKey = try(var.security_alert_policy.storage_account_access_key, null)
      storageEndpoint         = try(var.security_alert_policy.storage_endpoint, null)
    }
  }
  locks = [
    azurerm_mssql_managed_instance.this.id
  ]
  retry = var.retry.mssql_managed_instance_security_alert_policy

  timeouts {
    create = var.timeout.mssql_managed_instance_security_alert_policy.create
    delete = var.timeout.mssql_managed_instance_security_alert_policy.delete
    read   = var.timeout.mssql_managed_instance_security_alert_policy.read
    update = var.timeout.mssql_managed_instance_security_alert_policy.update
  }

  depends_on = [
    azurerm_mssql_managed_instance_active_directory_administrator.this,
  ]
}

resource "azurerm_mssql_managed_instance_transparent_data_encryption" "this" {
  count = var.transparent_data_encryption == {} ? 0 : 1

  managed_instance_id   = azurerm_mssql_managed_instance.this.id
  auto_rotation_enabled = var.transparent_data_encryption.auto_rotation_enabled
  key_vault_key_id      = var.transparent_data_encryption.key_vault_key_id

  dynamic "timeouts" {
    for_each = var.transparent_data_encryption.timeouts == null ? [] : [var.transparent_data_encryption.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azapi_resource_action.mssql_managed_instance_security_alert_policy,
  ]
}

# API:
# https://learn.microsoft.com/en-us/rest/api/sql/managed-instance-vulnerability-assessments/create-or-update?view=rest-sql-2023-08-01-preview&tabs=HTTP
#
# Note that user assigned identities are not support for vulnerability assessments, so must use user assigned & system assigned, or just system assigned.
# https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-vulnerability-assessment-storage?view=azuresql#store-va-scan-results-for-azure-sql-managed-instance-in-a-storage-account-that-can-be-accessed-behind-a-firewall-or-vnet
resource "azapi_resource_action" "mssql_managed_instance_vulnerability_assessment" {
  count = var.vulnerability_assessment == null ? 0 : 1

  method      = "PUT"
  resource_id = "${azurerm_mssql_managed_instance.this.id}/vulnerabilityAssessments/default"
  type        = "Microsoft.Sql/managedInstances/vulnerabilityAssessments@2023-08-01-preview"
  body = {
    properties = {
      storageAccountAccessKey = try(var.vulnerability_assessment.storage_account_access_key, null)
      storageContainerPath    = try(var.vulnerability_assessment.storage_container_path, null)
      storageContainerSasKey  = try(var.vulnerability_assessment.storage_container_sas_key, null)
      recurringScans = var.vulnerability_assessment.recurring_scans != {} ? {
        isEnabled               = try(var.vulnerability_assessment.recurring_scans.enabled, true)
        emailSubscriptionAdmins = try(var.vulnerability_assessment.recurring_scans.email_subscription_admins, true),
        emails                  = try(var.vulnerability_assessment.recurring_scans.emails, [])
      } : null
    }
  }
  locks = [
    azurerm_mssql_managed_instance.this.id
  ]

  depends_on = [
    azurerm_mssql_managed_instance_transparent_data_encryption.this,
  ]
}

# this is required for vulnerability assessments to function - user assigned identities are not supported
# https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-vulnerability-assessment-storage?view=azuresql
resource "azurerm_role_assignment" "sqlmi_system_assigned" {
  count = var.vulnerability_assessment == null ? 0 : 1

  principal_id         = jsondecode(data.azapi_resource.identity.output).identity.principal_id
  scope                = var.storage_account_resource_id
  role_definition_name = "Storage Blob Data Contributor"
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_mssql_managed_instance.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_mssql_managed_instance.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# identity is done via an azapi_resource_action further on, because of this bug that
# prevents system & user assigned identities being set at the same time.
# https://github.com/hashicorp/terraform-provider-azurerm/issues/19802
resource "azapi_resource_action" "sql_managed_instance_patch_identities" {
  count = (var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0) ? 1 : 0

  method      = "PATCH"
  resource_id = azurerm_mssql_managed_instance.this.id
  type        = "Microsoft.Sql/managedInstances@2023-05-01-preview"
  body = {
    identity = {
      type = local.managed_identities.system_assigned_user_assigned.this.type
      userAssignedIdentities = (local.managed_identities.system_assigned_user_assigned.this.type == "UserAssigned") || (local.managed_identities.system_assigned_user_assigned.this.type == "SystemAssigned, UserAssigned") ? {
        for id in tolist(local.managed_identities.system_assigned_user_assigned.this.user_assigned_resource_ids) : id => {}
      } : null
    },
    properties = {
      primaryUserAssignedIdentityId = length(local.managed_identities.system_assigned_user_assigned.this.user_assigned_resource_ids) > 0 ? tolist(local.managed_identities.system_assigned_user_assigned.this.user_assigned_resource_ids)[0] : null
    }
  }
  locks = [
    azurerm_mssql_managed_instance.this.id
  ]
  retry = var.retry.sql_managed_instance_patch_identities

  timeouts {
    create = var.timeout.sql_managed_instance_patch_identities.create
    delete = var.timeout.sql_managed_instance_patch_identities.delete
    read   = var.timeout.sql_managed_instance_patch_identities.read
    update = var.timeout.sql_managed_instance_patch_identities.update
  }

  depends_on = [
    azapi_resource_action.mssql_managed_instance_vulnerability_assessment,
  ]
}

data "azurerm_resource_group" "parent" {
  name = azurerm_mssql_managed_instance.this.resource_group_name
}

data "azapi_resource" "identity" {
  name                   = azurerm_mssql_managed_instance.this.name
  parent_id              = data.azurerm_resource_group.parent.id
  type                   = "Microsoft.Sql/managedInstances@2023-05-01-preview"
  response_export_values = ["identity"]
}

resource "azapi_resource_action" "sql_advanced_threat_protection" {
  method      = "PUT"
  resource_id = "${azurerm_mssql_managed_instance.this.id}/advancedThreatProtectionSettings/Default"
  type        = "Microsoft.Sql/managedInstances/advancedThreatProtectionSettings@2023-08-01-preview"
  body = {
    properties = {
      state = var.advanced_threat_protection_enabled ? "Enabled" : "Disabled"
    }
  }
  locks = [
    azurerm_mssql_managed_instance.this.id
  ]
  retry = var.retry.sql_advanced_threat_protection

  timeouts {
    create = var.timeout.sql_advanced_threat_protection.create
    delete = var.timeout.sql_advanced_threat_protection.delete
    read   = var.timeout.sql_advanced_threat_protection.read
    update = var.timeout.sql_advanced_threat_protection.update
  }

  depends_on = [
    azapi_resource_action.sql_managed_instance_patch_identities,
  ]
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_mssql_managed_instance.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories

    content {
      category = metric.value
    }
  }
}
