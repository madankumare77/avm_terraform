# Resource Group
resource_group_name     = "rg-infosys-ccd-prod-004"
resource_group_location = "centralindia"

# Network Security Group
nsg_apim_name = "nsg-apim-infosys-prod-004"

# Virtual Network
virtual_network_name = "vnet-infosys-ccd-prod-004"
vnet_address_space   = "10.30.0.0/24"

# Subnets
firewall_subnet_address_prefix           = "10.30.0.0/26"
apim_subnet_name                         = "snet-apim"
apim_subnet_address_prefix               = "10.30.0.64/27"
private_endpoint_subnet_name             = "snet-pe"
private_endpoint_subnet_address_prefix   = "10.30.0.128/27"

# Power Platform
power_platform_region = "India"

# PP subnet in primary VNet
pp_subnet_name           = "snet-pp-agent"
pp_subnet_address_prefix = "10.30.0.96/27"

# PP secondary VNet (paired region)
pp_secondary_vnet_name             = "vnet-pp-infosys-prod"
pp_secondary_vnet_address_space    = "10.31.0.0/24"
pp_secondary_subnet_address_prefix = "10.31.0.0/26"

# VNet Peering between primary and secondary PP VNets
enable_vnet_peering = true

# Key Vault
key_vault_name = "kv-infosys-ccd-prod-004"

# Azure Firewall
firewall_policy_name    = "afwp-infosys-ccd-prod-004"
firewall_name           = "afw-infosys-ccd-prod-004"
firewall_public_ip_name = "pip-afw-infosys-ccd-prod-004"

# API Management
apim_name     = "apim-infosys-ccd-prod-004"
apim_sku_name = "Developer_1"    #"Premium_1"   #"PremiumV2_1" not support in Cind  #"StandardV2_1" not support in for internal VNet

# Power Platform Enterprise Policy
pp_enterprise_policy_name = "ep-infosys-ccd-prod-004"


# route table
route_table_name = "rt-infosys-ccd-prod-004"


#Service Name: "apim-infosys-ccd-prod-004"): performing CreateOrUpdate: unexpected status 400 (400 Bad Request) with error: ManagingVirtualNetworkConfigurationNotSupported: Setting up 'Internal' Internal Virtual Network Type is not supported for Sku Type 'StandardV2'.