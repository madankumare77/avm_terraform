variable "enable_virtual_networks" {
  type    = bool
  default = false
}
variable "enable_nsg" {
  description = "Enable creation of Network Security Groups"
  type        = bool
  default     = false
}