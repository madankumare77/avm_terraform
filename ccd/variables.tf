variable "resource_group_name" {
  type        = string
  default     = ""
  description = "The name of the resource group"
}

variable "resource_group_location" {
  type        = string
  default     = ""
  description = "The location of the resource group"
}

variable "nsg_apim_name" {
  type        = string
  description = "The name of the APIM Network Security Group"
}

variable "virtual_network_name" {
  type        = string
  description = "The name of the Virtual Network"
}

variable "vnet_address_space" {
  type        = string
  description = "The address space of the Virtual Network (CIDR)"
}

variable "firewall_subnet_address_prefix" {
  type        = string
  description = "Address prefix for the AzureFirewallSubnet"
}

variable "apim_subnet_name" {
  type        = string
  description = "The name of the APIM subnet"
}

variable "apim_subnet_address_prefix" {
  type        = string
  description = "Address prefix for the APIM subnet"
}

variable "private_endpoint_subnet_name" {
  type        = string
  description = "The name of the private endpoint subnet"
}

variable "private_endpoint_subnet_address_prefix" {
  type        = string
  description = "Address prefix for the private endpoint subnet"
}

variable "power_platform_region" {
  type        = string
  description = "The Power Platform region (e.g., 'United States', 'UK', 'Europe'). Determines paired Azure regions for VNet creation."

  validation {
    condition = contains([
      "United States", "South Africa", "UK", "Japan", "India", "France",
      "Europe", "Germany", "Switzerland", "Canada", "Brazil", "Australia",
      "Asia", "UAE", "Korea", "Norway", "Singapore", "Sweden", "Italy", "US Government"
    ], var.power_platform_region)
    error_message = "Invalid Power Platform region. Must be one of: United States, South Africa, UK, Japan, India, France, Europe, Germany, Switzerland, Canada, Brazil, Australia, Asia, UAE, Korea, Norway, Singapore, Sweden, Italy, US Government."
  }

  validation {
    condition     = var.power_platform_region != "" 
    error_message = "Power Platform region must not be empty. Both paired Azure regions are required for enterprise policy deployment."
  }
}

variable "pp_subnet_name" {
  type        = string
  description = "The name of the Power Platform delegated subnet in the primary VNet"
}

variable "pp_subnet_address_prefix" {
  type        = string
  description = "Address prefix for the Power Platform subnet in the primary VNet"
}

variable "pp_secondary_vnet_name" {
  type        = string
  description = "Name prefix for the secondary Power Platform VNet (paired region name will be appended)"
}

variable "pp_secondary_vnet_address_space" {
  type        = string
  description = "Address space for the secondary Power Platform VNet in the paired region"
}

variable "pp_secondary_subnet_address_prefix" {
  type        = string
  description = "Subnet address prefix for the Power Platform delegated subnet in the secondary VNet"
}

variable "enable_vnet_peering" {
  type        = bool
  description = "Whether to create VNet peering between the primary and secondary Power Platform VNets. If false, ensure VNets are reachable via another mechanism (e.g., firewall, ExpressRoute)."
  default     = false
}

variable "key_vault_name" {
  type        = string
  description = "The name of the Azure Key Vault"
}

variable "firewall_policy_name" {
  type        = string
  description = "The name of the Azure Firewall Policy"
}

variable "firewall_name" {
  type        = string
  description = "The name of the Azure Firewall"
}

variable "firewall_public_ip_name" {
  type        = string
  description = "The name of the Azure Firewall public IP"
}

variable "apim_name" {
  type        = string
  description = "The name of the API Management service"
}

variable "apim_sku_name" {
  type        = string
  description = "The SKU name of the API Management service (e.g., StandardV2_1, PremiumV2_1)"
}

variable "pp_enterprise_policy_name" {
  type        = string
  description = "The name of the Power Platform Enterprise Policy for Network Injection"
}

variable "route_table_name" {
  type        = string
  description = "The name of the route table"
}

