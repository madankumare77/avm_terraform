terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # azapi = {
    #   source  = "azure/azapi"
    #   version = ">= 2.10.0"
    # }
  }
}

provider "azurerm" {
  features {}
  subscription_id =  "8d18e83d-3598-4679-a580-6936a7e57638"
}
