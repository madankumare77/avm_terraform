variable "subscription_id" {
    type = string
    sensitive = true
    description = "subcription ID will call from Github environmets secrets in github workflow"
 
}
variable "tenant_id" {
    type = string
    sensitive = true
    description = "tanent ID will call from Github environmets secrets in github workflow"
}
 
 
variable "sqlmi_admin_password" {
  description = "Admin password for the DR SQL Managed Instance"
  type        = string
  sensitive   = true
  validation {
    condition  = length(var.sqlmi_admin_password) >= 16 && can(regex("[A-Z]", var.sqlmi_admin_password)) && can(regex("[a-z]", var.sqlmi_admin_password)) && can(regex("[0-9]", var.sqlmi_admin_password)) && can(regex("[^A-Za-z0-9]", var.sqlmi_admin_password))
    error_message = "admin password must be at least 16 characters long and include at least one uppercase letter, one lowercase letter, one number, and one special character."
  }
}
variable "sqlmi_administrator_login" {
  description = "Admin username for the DR SQL Managed Instance"
  type = string
}
 