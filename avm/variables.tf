variable "enable_virtual_networks" {
  type    = bool
  default = true
}
variable "enable_nsg" {
  description = "Enable creation of Network Security Groups"
  type        = bool
  default     = false
}
variable "enable_kv" {
  type    = bool
  default = false
}
variable "enable_log_analytics_workspace" {
  type    = bool
  default = true
}
variable "enable_storage_account" {
  type    = bool
  default = true
}
variable "enable_function_app" {
  type    = bool
  default = true
}

variable "enable_app_service_plan" {
  type    = bool
  default = true
}
variable "enable_user_assigned_identities" {
  type    = bool
  default = true
}
variable "enable_application_insights" {
  type    = bool
  default = true
}