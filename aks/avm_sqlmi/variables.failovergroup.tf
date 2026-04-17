variable "failover_group" {
  type = map(object({
    location                                  = optional(string)
    name                                      = optional(string)
    partner_managed_instance_id               = optional(string)
    readonly_endpoint_failover_policy_enabled = optional(bool)
    read_write_endpoint_failover_policy = optional(object({
      grace_minutes = optional(number)
      mode          = optional(string)
    }))
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  }))
  default     = {}
  description = <<-DESCRIPTION

Map of failover groups.  There can only be one failover group in the map.

 - `location` - (Required) The Azure Region where the Managed Instance Failover Group should exist. Changing this forces a new resource to be created.
 - `name` - (Required) The name which should be used for this Managed Instance Failover Group. Changing this forces a new resource to be created.
 - `partner_managed_instance_id` - (Required) The ID of the Azure SQL Managed Instance which will be replicated to. Changing this forces a new resource to be created.
 - `readonly_endpoint_failover_policy_enabled` - (Optional) Failover policy for the read-only endpoint. Defaults to `true`.

 ---
 `read_write_endpoint_failover_policy` block supports the following:
 - `grace_minutes` - (Optional) Applies only if `mode` is `Automatic`. The grace period in minutes before failover with data loss is attempted.
 - `mode` - (Required) The failover mode. Possible values are `Automatic` or `Manual`.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 30 minutes) Used when creating the Managed Instance Failover Group.
 - `delete` - (Defaults to 30 minutes) Used when deleting the Managed Instance Failover Group.
 - `read` - (Defaults to 5 minutes) Used when retrieving the Managed Instance Failover Group.
 - `update` - (Defaults to 30 minutes) Used when updating the Managed Instance Failover Group.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.failover_group) <= 1
    error_message = "The 'failover_group' map must contain 0 or 1 items."
  }
}
