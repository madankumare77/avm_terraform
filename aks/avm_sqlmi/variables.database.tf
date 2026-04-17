variable "databases" {
  type = map(object({
    name                      = string
    short_term_retention_days = optional(number)
    tags                      = optional(map(string))
    long_term_retention_policy = optional(object({
      monthly_retention = optional(string)
      week_of_year      = optional(number)
      weekly_retention  = optional(string)
      yearly_retention  = optional(string)
    }))
    point_in_time_restore = optional(object({
      restore_point_in_time = string
      source_database_id    = string
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
 - `name` - (Required) The name of the Managed Database to create. Changing this forces a new resource to be created.
 - `short_term_retention_days` - (Optional) The backup retention period in days. This is how many days Point-in-Time Restore will be supported.
 - `tags` - (Optional) A mapping of tags to assign to the managed database.

 ---
 `long_term_retention_policy` block supports the following:
 - `monthly_retention` - (Optional) The monthly retention policy for an LTR backup in an ISO 8601 format. Valid value is between 1 to 120 months. e.g. `P1Y`, `P1M`, `P4W` or `P30D`.
 - `week_of_year` - (Optional) The week of year to take the yearly backup. Value has to be between `1` and `52`.
 - `weekly_retention` - (Optional) The weekly retention policy for an LTR backup in an ISO 8601 format. Valid value is between 1 to 520 weeks. e.g. `P1Y`, `P1M`, `P1W` or `P7D`.
 - `yearly_retention` - (Optional) The yearly retention policy for an LTR backup in an ISO 8601 format. Valid value is between 1 to 10 years. e.g. `P1Y`, `P12M`, `P52W` or `P365D`.

 ---
 `point_in_time_restore` block supports the following:
 - `restore_point_in_time` - (Required) The point in time for the restore from `source_database_id`. Changing this forces a new resource to be created.
 - `source_database_id` - (Required) The source database id that will be used to restore from. Changing this forces a new resource to be created.

 ---
 `timeouts` block supports the following:
 - `create` - (Defaults to 30 minutes) Used when creating the Mssql Managed Database.
 - `delete` - (Defaults to 30 minutes) Used when deleting the Mssql Managed Database.
 - `read` - (Defaults to 5 minutes) Used when retrieving the Mssql Managed Database.
 - `update` - (Defaults to 30 minutes) Used when updating the Mssql Managed Database.
DESCRIPTION
  nullable    = false
}
