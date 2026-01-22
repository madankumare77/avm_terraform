# SQL Managed instance
1. Rquired vnet, delegated subnet, nsg with dedicated nsg rules, route table
2. 

1. for gro replication failover, 
The managed instance you choose as the secondary must be from a different region. The secondary also needs to be an empty managed instance that has the same max-size and dns-prefix as the primary.

vnet peering required, no overlaping of address spaces.

For SQL Managed Instance, the backup redundancy can be LRS / ZRS / GRS / GZRS, but ZRS/GZRS are only available in certain regions. If your module’s default is ZRS (common), creating in South India (or another region without ZRS for MI backups) will fail exactly like this. The safe, broadly supported choice is GRS; use that or another redundancy explicitly supported in your region


2. Failover Groups do not require paired regions.
They only require:

Two SQL Managed Instances
In two Azure regions
VNet connectivity (peering/VPN/ExpressRoute)
Same DNS Zone (secondary must be created using dns_zone_partner_id)
if managed dns zone then this dns zone required to integate with both vnets.
Same storage size
Secondary is empty
Both VNets non-overlapping
Required NSG ports open: 5022 and 11000–11999

So Central India → South India failover is supported as long as quota exists in South India.






#############################################################################################
#############################################################################################
    # vnet1 = {
    #   create_vnet         = false
    #   name                = "vent-infy-is"
    #   resource_group_name = data.azurerm_resource_group.rg.name

    #   # list the subnets you want to reference from that existing vnet
    #   existing_subnets = {
    #     snetmi = { name = "subnet-mi" }
    #     snet1 = { name = "snet-pvt" }
    #     snet2 = { name = "snet-test" }
    #   }
    # }
    # vnet-dr = {
    #   create_vnet            = true
    #   parent_id             = data.azurerm_resource_group.rg_dr.id
    #   name                   = "vent-infy-is-dr"
    #   location               = data.azurerm_resource_group.rg_dr.location
    #   address_space          = ["10.1.0.0/24"]
    #   enable_ddos_protection = false
    #   dns_servers            = ["168.63.129.16"]
    #   tags = {
    #     created_by = "terraform"
    #   }
    #   subnet_configs = {
    #     snetmi = {
    #       name           = "subnet-mi"
    #       address_prefix = ["10.1.0.0/26"]
    #       nsg_key        = "nsg_dr"
    #       route_table   = { id = module.avm-res-network-routetable.resource_id }

    #       delegation = {
    #         name = "managedinstancedelegation"
    #         service_delegation = {
    #           name    = "Microsoft.Sql/managedInstances"
    #           actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    #         }
    #       }
    #     }
    #     snet1 = {
    #       name           = "subnet-pvt"
    #       address_prefix = ["10.1.0.64/26"]
    #       nsg_key        = "nsg_dr"
    #       route_table   = { id = module.avm-res-network-routetable.resource_id }
    #     }
    #   }
    # }


#############################################################################################
#############################################################################################
    # nsg_dr = {
    #   create_nsg = true
    #   nsg_name   = "mi-security-group-dr"
    #   location   = data.azurerm_resource_group.rg_dr.location
    #   rg_name    = data.azurerm_resource_group.rg_dr.name

    #   security_rules = [
    #     {
    #       name                       = "allow_management_inbound"
    #       priority                   = 106
    #       direction                  = "Inbound"
    #       access                     = "Allow"
    #       protocol                   = "Tcp"
    #       source_address_prefix      = "*"
    #       destination_address_prefix = "*"
    #       source_port_range          = "*"
    #       destination_port_ranges    = ["9000", "9003", "1438", "1440", "1452"]
    #     },
    #     {
    #       name                       = "allow_misubnet_inbound"
    #       priority                   = 200
    #       direction                  = "Inbound"
    #       access                     = "Allow"
    #       protocol                   = "*"
    #       source_address_prefix      = "*"
    #       destination_address_prefix = "10.1.0.0/24"
    #       source_port_range          = "*"
    #       destination_port_range     = "*"
    #     },
    #     {
    #       access                     = "Allow"
    #       direction                  = "Inbound"
    #       name                       = "allow_health_probe_inbound"
    #       priority                   = 300
    #       protocol                   = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       source_address_prefix      = "AzureLoadBalancer"
    #       source_port_range          = "*"

    #     },
    #     {
    #       access                     = "Allow"
    #       direction                  = "Inbound"
    #       name                       = "allow_tds_inbound"
    #       priority                   = 1000
    #       protocol                   = "Tcp"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "1433"
    #       source_address_prefix      = "VirtualNetwork"
    #       source_port_range          = "*"

    #     },
    #     {
    #       access                     = "Deny"
    #       direction                  = "Inbound"
    #       name                       = "deny_all_inbound"
    #       priority                   = 4096
    #       protocol                   = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #     },
    #     {
    #       access                     = "Allow"
    #       direction                  = "Outbound"
    #       name                       = "allow_management_outbound"
    #       priority                   = 106
    #       protocol                   = "Tcp"
    #       destination_address_prefix = "*"
    #       destination_port_ranges    = ["80", "443", "12000"]
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #     },
    #     {
    #       access                     = "Allow"
    #       direction                  = "Outbound"
    #       name                       = "allow_misubnet_outbound"
    #       priority                   = 200
    #       protocol                   = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       source_address_prefix      = "10.1.0.64/26"
    #       source_port_range          = "*"
    #     },
    #     {
    #       access                     = "Deny"
    #       direction                  = "Outbound"
    #       name                       = "deny_all_outbound"
    #       priority                   = 4096
    #       protocol                   = "*"
    #       destination_address_prefix = "*"
    #       destination_port_range     = "*"
    #       source_address_prefix      = "*"
    #       source_port_range          = "*"
    #     }
    #   ]
    #   tags = {
    #     created_by = "terraform"
    #   }
    # }