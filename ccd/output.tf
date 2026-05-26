############## Resource Group ##############

output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.avm-res-resources-resourcegroup.name
}

output "resource_group_id" {
  description = "The resource ID of the resource group"
  value       = module.avm-res-resources-resourcegroup.resource_id
}

############## Network Security Group ##############

output "nsg_apim_id" {
  description = "The resource ID of the APIM NSG"
  value       = module.avm-res-network-networksecuritygroup_apim.resource_id
}

############## Virtual Network ##############

output "virtual_network_id" {
  description = "The resource ID of the Virtual Network"
  value       = module.avm-res-network-virtualnetwork.resource_id
}

output "virtual_network_name" {
  description = "The name of the Virtual Network"
  value       = module.avm-res-network-virtualnetwork.name
}

output "subnet_firewall_id" {
  description = "The resource ID of the AzureFirewallSubnet"
  value       = module.avm-res-network-virtualnetwork.subnets["subnet1"].resource_id
}

output "subnet_apim_id" {
  description = "The resource ID of the APIM subnet"
  value       = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id
}

output "subnet_private_endpoint_id" {
  description = "The resource ID of the private endpoint subnet"
  value       = module.avm-res-network-virtualnetwork.subnets["subnet3"].resource_id
}

output "subnet_pp_primary_id" {
  description = "The resource ID of the Power Platform subnet in the primary VNet"
  value       = module.avm-res-network-virtualnetwork.subnets["subnet4"].resource_id
}

############## Power Platform Secondary VNet ##############

output "pp_secondary_vnet_id" {
  description = "The resource ID of the secondary Power Platform VNet (paired region)"
  value       = length(module.pp_secondary_vnet) > 0 ? module.pp_secondary_vnet[0].resource_id : null
}

output "pp_secondary_vnet_name" {
  description = "The name of the secondary Power Platform VNet"
  value       = length(module.pp_secondary_vnet) > 0 ? module.pp_secondary_vnet[0].name : null
}

output "pp_secondary_subnet_id" {
  description = "The resource ID of the Power Platform delegated subnet in the secondary VNet"
  value       = length(module.pp_secondary_vnet) > 0 ? module.pp_secondary_vnet[0].subnets["pp_subnet"].resource_id : null
}

output "pp_secondary_region" {
  description = "The Azure region of the secondary Power Platform VNet"
  value       = local.pp_secondary_region
}

output "vnet_peering_warning" {
  description = "Warning message when VNet peering is disabled"
  value       = var.enable_vnet_peering ? "VNet peering is enabled between primary and secondary VNets." : "WARNING: VNet peering is DISABLED. Ensure the primary and secondary Power Platform VNets are reachable via another mechanism (e.g., Azure Firewall, ExpressRoute, or VPN Gateway) for Power Platform VNet integration to function correctly."
}

############## Key Vault ##############

output "key_vault_id" {
  description = "The resource ID of the Key Vault"
  value       = module.avm-res-keyvault-vault.resource_id
}

# output "key_vault_uri" {
#   description = "The URI of the Key Vault"
#   value       = module.avm-res-keyvault-vault.resource.properties.vaultUri
# }

############## Azure Firewall ##############

output "firewall_policy_id" {
  description = "The resource ID of the Firewall Policy"
  value       = module.avm-res-network-firewallpolicy.resource_id
}

output "firewall_id" {
  description = "The resource ID of the Azure Firewall"
  value       = module.avm-res-network-azurefirewall.resource_id
}

output "firewall_private_ip" {
  description = "The private IP address of the Azure Firewall"
  value       = module.avm-res-network-azurefirewall.resource.ip_configuration[0].private_ip_address
}

############## API Management ##############

output "apim_id" {
  description = "The resource ID of the API Management service"
  value       = module.avm-res-apimanagement-service.resource_id
}

