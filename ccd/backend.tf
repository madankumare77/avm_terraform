# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-infosys-dev-01"
#     storage_account_name = "rginfosysdev0183f4"
#     container_name       = "tfstate"
#     key                  = "infosys-ccd.terraform.tfstate"
#     use_azuread_auth     = true
#   }
# }
