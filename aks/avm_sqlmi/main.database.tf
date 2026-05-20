resource "azurerm_mssql_managed_database" "this" {
  for_each = var.databases

  managed_instance_id       = azurerm_mssql_managed_instance.this.id
  name                      = each.value.name
  short_term_retention_days = each.value.short_term_retention_days
  tags                      = each.value.tags

  dynamic "long_term_retention_policy" {
    for_each = each.value.long_term_retention_policy == null ? [] : [each.value.long_term_retention_policy]

    content {
      monthly_retention = long_term_retention_policy.value.monthly_retention
      week_of_year      = long_term_retention_policy.value.week_of_year
      weekly_retention  = long_term_retention_policy.value.weekly_retention
      yearly_retention  = long_term_retention_policy.value.yearly_retention
    }
  }
  dynamic "point_in_time_restore" {
    for_each = each.value.point_in_time_restore == null ? [] : [each.value.point_in_time_restore]

    content {
      restore_point_in_time = point_in_time_restore.value.restore_point_in_time
      source_database_id    = point_in_time_restore.value.source_database_id
    }
  }
  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azapi_resource_action.sql_advanced_threat_protection,
  ]
}

