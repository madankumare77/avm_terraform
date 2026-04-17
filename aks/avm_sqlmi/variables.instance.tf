variable "administrator_login" {
  type        = string
  description = "(Required) The administrator login name for the new SQL Managed Instance. Changing this forces a new resource to be created."
  nullable    = false
}

variable "administrator_login_password" {
  type        = string
  description = "(Required) The password associated with the `administrator_login` user. Needs to comply with Azure's [Password Policy](https://msdn.microsoft.com/library/ms161959.aspx)"
  nullable    = false
  sensitive   = true
}

variable "license_type" {
  type        = string
  description = "(Required) What type of license the Managed Instance will use. Possible values are `LicenseIncluded` and `BasePrice`."
  nullable    = false
}

variable "sku_name" {
  type        = string
  description = "(Required) Specifies the SKU Name for the SQL Managed Instance. Valid values include `GP_Gen4`, `GP_Gen5`, `GP_Gen8IM`, `GP_Gen8IH`, `BC_Gen4`, `BC_Gen5`, `BC_Gen8IM` or `BC_Gen8IH`."
  nullable    = false
}

variable "storage_size_in_gb" {
  type        = number
  description = "(Required) Maximum storage space for the SQL Managed instance. This should be a multiple of 32 (GB)."
  nullable    = false
}

variable "subnet_id" {
  type        = string
  description = "(Required) The subnet resource id that the SQL Managed Instance will be associated with. Changing this forces a new resource to be created."
  nullable    = false
}

variable "vcores" {
  type        = number
  description = "(Required) Number of cores that should be assigned to the SQL Managed Instance. Values can be `8`, `16`, or `24` for Gen4 SKUs, or `4`, `6`, `8`, `10`, `12`, `16`, `20`, `24`, `32`, `40`, `48`, `56`, `64`, `80`, `96` or `128` for Gen5 SKUs."
  nullable    = false
}

variable "active_directory_administrator" {
  type = object({
    azuread_authentication_only = optional(bool)
    login_username              = optional(string)
    object_id                   = optional(string)
    tenant_id                   = optional(string)
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  })
  default     = {}
  description = <<-DESCRIPTION
 - `azuread_authentication_only` - (Optional) When `true`, only permit logins from AAD users and administrators. When `false`, also allow local database users.
 - `login_username` - (Required) The login name of the principal to set as the Managed Instance Administrator.
 - `object_id` - (Required) The Object ID of the principal to set as the Managed Instance Administrator.
 - `tenant_id` - (Required) The Azure Active Directory Tenant ID.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 30 minutes) Used when creating the SQL Active Directory Administrator.
 - `delete` - (Defaults to 30 minutes) Used when deleting the SQL Active Directory Administrator.
 - `read` - (Defaults to 5 minutes) Used when retrieving the SQL Active Directory Administrator.
 - `update` - (Defaults to 30 minutes) Used when updating the SQL Active Directory Administrator.
DESCRIPTION
  nullable    = false
}

variable "advanced_threat_protection_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Whether to enabled Defender for SQL Advanced Threat Protection."
  nullable    = false
}

variable "collation" {
  type        = string
  default     = null
  description = "(Optional) Specifies how the SQL Managed Instance will be collated. Default value is `SQL_Latin1_General_CP1_CI_AS`. Changing this forces a new resource to be created."
}

variable "dns_zone_partner_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the SQL Managed Instance which will share the DNS zone. This is a prerequisite for creating an `azurerm_mssql_managed_instance_failover_group`. Setting this after creation forces a new resource to be created."
}

variable "maintenance_configuration_name" {
  type        = string
  default     = null
  description = "(Optional) The name of the Public Maintenance Configuration window to apply to the SQL Managed Instance. Valid values include `SQL_Default` or an Azure Location in the format `SQL_{Location}_MI_{Size}`(for example `SQL_EastUS_MI_1`). Defaults to `SQL_Default`."
}

variable "minimum_tls_version" {
  type        = string
  default     = "1.2"
  description = "(Optional) The Minimum TLS Version. Default value is `1.2` Valid values include `1.0`, `1.1`, `1.2`."
}

variable "proxy_override" {
  type        = string
  default     = null
  description = "(Optional) Specifies how the SQL Managed Instance will be accessed. Default value is `Default`. Valid values include `Default`, `Proxy`, and `Redirect`."
}

variable "public_data_endpoint_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Is the public data endpoint enabled? Default value is `false`."
}

variable "security_alert_policy" {
  type = object({
    disabled_alerts              = optional(set(string))
    email_account_admins_enabled = optional(bool)
    email_addresses              = optional(set(string))
    enabled                      = optional(bool)
    retention_days               = optional(number)
    storage_account_access_key   = optional(string)
    storage_endpoint             = optional(string)
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  })
  default     = {}
  description = <<-DESCRIPTION
 - `disabled_alerts` - (Optional) Specifies an array of alerts that are disabled. Possible values are `Sql_Injection`, `Sql_Injection_Vulnerability`, `Access_Anomaly`, `Data_Exfiltration`, `Unsafe_Action` and `Brute_Force`.
 - `email_account_admins_enabled` - (Optional) Boolean flag which specifies if the alert is sent to the account administrators or not. Defaults to `false`.
 - `email_addresses` - (Optional) Specifies an array of email addresses to which the alert is sent.
 - `enabled` - (Optional) Specifies the state of the Security Alert Policy, whether it is enabled or disabled. Possible values are `true`, `false`.
 - `retention_days` - (Optional) Specifies the number of days to keep in the Threat Detection audit logs. Defaults to `0`.
 - `storage_account_access_key` - (Optional) Specifies the identifier key of the Threat Detection audit storage account. This is mandatory when you use `storage_endpoint` to specify a storage account blob endpoint.
 - `storage_endpoint` - (Optional) Specifies the blob storage endpoint (e.g. https://example.blob.core.windows.net). This blob storage will hold all Threat Detection audit logs.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 30 minutes) Used when creating the MS SQL Managed Instance Security Alert Policy.
 - `delete` - (Defaults to 30 minutes) Used when deleting the MS SQL Managed Instance Security Alert Policy.
 - `read` - (Defaults to 5 minutes) Used when retrieving the MS SQL Managed Instance Security Alert Policy.
 - `update` - (Defaults to 30 minutes) Used when updating the MS SQL Managed Instance Security Alert Policy.
DESCRIPTION
  nullable    = false
}

variable "storage_account_resource_id" {
  type        = string
  default     = null
  description = <<-DESCRIPTION
(Optional) Storage Account to store vulnerability assessments.

The System Assigned Managed Identity will be granted Storage Blob Data Contributor over this storage account.

Note these limitations documented in Microsoft Learn - <https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-vulnerability-assessment-storage?view=azuresql#store-va-scan-results-for-azure-sql-managed-instance-in-a-storage-account-that-can-be-accessed-behind-a-firewall-or-vnet>

* User Assigned MIs are not supported
* The storage account firewall public network access must be allowed.  If "Enabled from selected virtual networks and IP addresses" is set (recommended), the SQL MI subnet ID must be added to the storage account firewall.

DESCRIPTION
}

variable "storage_account_type" {
  type        = string
  default     = "ZRS"
  description = "(Optional) Specifies the storage account type used to store backups for this database. Changing this forces a new resource to be created. Possible values are `GRS`, `LRS` and `ZRS`. Defaults to `GRS`."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = <<-DESCRIPTION
 - `create` - (Defaults to 24 hours) Used when creating the Microsoft SQL Managed Instance.
 - `delete` - (Defaults to 24 hours) Used when deleting the Microsoft SQL Managed Instance.
 - `read` - (Defaults to 5 minutes) Used when retrieving the Microsoft SQL Managed Instance.
 - `update` - (Defaults to 24 hours) Used when updating the Microsoft SQL Managed Instance.
DESCRIPTION
}

variable "timezone_id" {
  type        = string
  default     = null
  description = "(Optional) The TimeZone ID that the SQL Managed Instance will be operating in. Default value is `UTC`. Changing this forces a new resource to be created."
}

variable "transparent_data_encryption" {
  type = object({
    auto_rotation_enabled = optional(bool)
    key_vault_key_id      = optional(string)
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  })
  default     = {}
  description = <<-DESCRIPTION
 - `auto_rotation_enabled` - (Optional) When enabled, the SQL Managed Instance will continuously check the key vault for any new versions of the key being used as the TDE protector. If a new version of the key is detected, the TDE protector on the SQL Managed Instance will be automatically rotated to the latest key version within 60 minutes.
 - `key_vault_key_id` - (Optional) To use customer managed keys from Azure Key Vault, provide the AKV Key ID. To use service managed keys, omit this field.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 30 minutes) Used when creating the MSSQL.
 - `delete` - (Defaults to 30 minutes) Used when deleting the MSSQL.
 - `read` - (Defaults to 5 minutes) Used when retrieving the MSSQL.
 - `update` - (Defaults to 30 minutes) Used when updating the MSSQL.
DESCRIPTION
}

variable "vulnerability_assessment" {
  type = object({
    storage_account_access_key = optional(string)
    storage_container_path     = optional(string)
    storage_container_sas_key  = optional(string)
    recurring_scans = optional(object({
      email_subscription_admins = optional(bool)
      emails                    = optional(list(string))
      enabled                   = optional(bool)
    }))
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  })
  default     = null
  description = <<-DESCRIPTION
 - `storage_account_access_key` - (Optional) Specifies the identifier key of the storage account for vulnerability assessment scan results. If `storage_container_sas_key` isn't specified, `storage_account_access_key` is required.  Set to `null` if the storage account is protected by a resource firewall.
 - `storage_container_path` - (Required) A blob storage container path to hold the scan results (e.g. <https://myStorage.blob.core.windows.net/VaScans/>).
 - `storage_container_sas_key` - (Optional) A shared access signature (SAS Key) that has write access to the blob container specified in `storage_container_path` parameter. If `storage_account_access_key` isn't specified, `storage_container_sas_key` is required.  Set to `null` if the storage account is protected by a resource firewall.

 ---
 `recurring_scans` block supports the following:
 - `email_subscription_admins` - (Optional) Boolean flag which specifies if the schedule scan notification will be sent to the subscription administrators. Defaults to `true`.
 - `emails` - (Optional) Specifies an array of e-mail addresses to which the scan notification is sent.
 - `enabled` - (Optional) Boolean flag which specifies if recurring scans is enabled or disabled. Defaults to `false`.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 60 minutes) Used when creating the Vulnerability Assessment.
 - `delete` - (Defaults to 60 minutes) Used when deleting the Vulnerability Assessment.
 - `read` - (Defaults to 5 minutes) Used when retrieving the Vulnerability Assessment.
 - `update` - (Defaults to 60 minutes) Used when updating the Vulnerability Assessment.
DESCRIPTION
}

variable "zone_redundant_enabled" {
  type        = bool
  default     = true
  description = "(Optional) If true, the SQL Managed Instance will be deployed with zone redundancy.  Defaults to `true`."
}

variable "database_format" {
  type        = string
}