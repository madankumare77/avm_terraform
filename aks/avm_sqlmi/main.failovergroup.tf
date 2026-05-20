resource "azurerm_mssql_managed_instance_failover_group" "this" {
  for_each = var.failover_group

  location                                  = each.value.location
  managed_instance_id                       = azurerm_mssql_managed_instance.this.id
  name                                      = each.value.name
  partner_managed_instance_id               = each.value.partner_managed_instance_id
  readonly_endpoint_failover_policy_enabled = each.value.readonly_endpoint_failover_policy_enabled

  dynamic "read_write_endpoint_failover_policy" {
    for_each = [each.value.read_write_endpoint_failover_policy]

    content {
      mode          = read_write_endpoint_failover_policy.value.mode
      grace_minutes = read_write_endpoint_failover_policy.value.grace_minutes
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
}

