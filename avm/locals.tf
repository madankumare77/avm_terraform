#--------------------------------------------------------------------
# Virtual Network and Subnet configurations
#--------------------------------------------------------------------
locals {
  virtual_networks = {
    # vnet1 = {
    #   create_vnet            = true
    #   name                   = "vent-name"
    #   location               = "centralindia"
    #   address_space          = ["101.122.96.0/24"]
    #   enable_ddos_protection = false
    #   dns_servers            = ["168.63.129.16"]
    #   tags = {
    #     created_by = "terraform"
    #   }

    #   subnet_configs = {
    #     snet1 = {
    #       name              = "snet1-test"
    #       address_prefix    = ["101.122.96.0/28"]
    #       service_endpoints = ["Microsoft.KeyVault"]
    #       nsg_key           = "nsg1"
    #     }

    #     snet2 = {
    #       name           = "snet2-test"
    #       address_prefix = ["101.122.96.64/28"]
    #       nsg_key        = "nsg2"
    #     }

    #     snet3 = {
    #       name              = "snet3-test"
    #       address_prefix    = ["101.122.96.32/28"]
    #       service_endpoints = ["Microsoft.Web"]
    #       nsg_key           = "nsg2"

    #       delegation = {
    #         name = "functionapp"
    #         service_delegation = {
    #           name    = "Microsoft.Web/serverFarms"
    #           actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    #         }
    #       }
    #     }
    #   }
    # }
    vnet1_manual = {
      create_vnet         = false
      name                = "vnet1-manual"
      resource_group_name = data.azurerm_resource_group.rg.name

      # list the subnets you want to reference from that existing vnet
      existing_subnets = {
        snet1 = { name = "snet1-manual" }
        snet2 = { name = "snet2-manual" }
      }
    }
  }
}

#--------------------------------------------------------------------
# Network Security Group configurations
#--------------------------------------------------------------------
locals {
  nsg_configs = {
    nsg1 = {
      create_nsg = true
      nsg_name   = "nsg-infy-test"
      location   = data.azurerm_resource_group.rg.location
      rg_name    = data.azurerm_resource_group.rg.name

      security_rules = [
        {
          name                       = "Allow-InBound"
          priority                   = 500
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "*"
          destination_address_prefix = "VirtualNetwork"
          source_port_range          = "*"
          destination_port_range     = "443"
        }
      ]
      tags = {
        created_by = "terraform"
      }
    }

    nsg2 = {
      create_nsg = false
      nsg_name   = "nsg-infy-manual"
      rg_name    = data.azurerm_resource_group.rg.name
      # location optional for lookup; NSG has a location but data source doesn't need it
    }
  }
}

#--------------------------------------------------------------------
#Key Vault configurations
#--------------------------------------------------------------------
locals {
  keyvault_configs = {
    # kv1 = {
    #   name                = "kv003-test-infy"
    #   location            = "centralindia"
    #   resource_group_name = data.azurerm_resource_group.rg.name

    #   soft_delete_retention_days      = 7
    #   purge_protection_enabled        = false
    #   legacy_access_policies_enabled  = false
    #   enabled_for_deployment          = true
    #   enabled_for_disk_encryption     = true
    #   enabled_for_template_deployment = true
    #   public_network_access_enabled   = false
    #   enable_telemetry                = false

    #   # Optional KV firewall settings. If you keep KV private-only, this is fine.
    #   network_acls = {
    #     bypass         = "AzureServices"
    #     default_action = "Deny"

    #     # We will convert these vnet/subnet keys -> subnet IDs using local.subnet_ids
    #     virtual_network_subnet_refs = [
    #       {
    #         vnet_key   = "vnet1"
    #         subnet_key = "snet1" # ✅ this is your snet1 in vnet1
    #       }
    #     ]
    #   }

    #   private_endpoints = {
    #     kvpe = {
    #       name       = "pvt-endpoint-kv003-test-infy"
    #       vnet_key   = "vnet1"
    #       subnet_key = "snet1" # ✅ use snet1 in vnet1
    #       # If you already have private DNS zone ids, place them here; otherwise keep empty.
    #       private_dns_zone_resource_ids = []
    #     }
    #   }

    #   diagnostic_settings = {
    #     kvdiag = {
    #       name = "diag-kv003-test-infy"
    #       # log_categories    = ["AuditEvent"]
    #       # metric_categories = ["AllMetrics"]
    #       workspace_resource_id = try(module.law[0].resource_id, null) # if you have LA workspace
    #     }
    #   }

    #   tags = {
    #     created_by = "terraform"
    #   }
    # }
    kv2 = {
      name                = "kv004-test-infy"
      location            = "centralindia"
      resource_group_name = data.azurerm_resource_group.rg.name

      soft_delete_retention_days      = 7
      purge_protection_enabled        = false
      legacy_access_policies_enabled  = false
      enabled_for_deployment          = true
      enabled_for_disk_encryption     = true
      enabled_for_template_deployment = true
      public_network_access_enabled   = false
      enable_telemetry                = false

      # Optional KV firewall settings. If you keep KV private-only, this is fine.
      network_acls = {
        bypass         = "AzureServices"
        default_action = "Deny"

        # We will convert these vnet/subnet keys -> subnet IDs using local.subnet_ids
        virtual_network_subnet_refs = [
          {
            vnet_key   = "vnet1_manual"
            subnet_key = "snet1"
          }
        ]
      }
      private_endpoints = {
        kvpe = {
          name       = "pvt-endpoint-kv004-test-infy"
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
          # If you already have private DNS zone ids, place them here; otherwise keep empty.
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        kvdiag = {
          name                  = "diag-kv004-test-infy"
          workspace_resource_id = try(module.law[0].resource_id, null) # if you have LA workspace
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
  }
}


#--------------------------------------------------------------------
# #Storage Account configurations
#--------------------------------------------------------------------
locals {
  storage_account_configs = {
    st1 = {
      name                              = "st003testinfy"
      resource_group_name               = data.azurerm_resource_group.rg.name
      location                          = data.azurerm_resource_group.rg.location
      account_tier                      = "Standard"
      account_replication_type          = "LRS"
      access_tier                       = "Hot"
      account_kind                      = "StorageV2"
      allow_nested_items_to_be_public   = false
      default_to_oauth_authentication   = true
      https_traffic_only_enabled        = true
      infrastructure_encryption_enabled = true
      local_user_enabled                = false
      min_tls_version                   = "TLS1_2"
      public_network_access_enabled     = false
      sftp_enabled                      = false
      shared_access_key_enabled         = false
      enable_telemetry                  = false


      network_rules_subnet_refs = [
        {
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
        }
      ]
      private_endpoints = {
        stpe = {
          name                          = "pe-st003testinfy-blob"
          vnet_key                      = "vnet1_manual"
          subnet_key                    = "snet1"
          subresource_name              = "blob"
          private_dns_zone_resource_ids = []
          tags                          = { env = "test" }
        }
      }
      diagnostic_settings_blob = {
        stdiag = {
          name                  = "diag-st003testinfy-blob"
          workspace_resource_id = try(module.law[0].resource_id, null)
          metric_categories     = ["Transaction", "Capacity"]
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
  }
}

#--------------------------------------------------------------------
# Function App configurations
#--------------------------------------------------------------------
locals {
  function_app_configs = {
    function1 = {
      name                                           = "infy-claims-function-app"
      location                                       = data.azurerm_resource_group.rg.location
      resource_group_name                            = data.azurerm_resource_group.rg.name
      kind                                           = "functionapp"
      os_type                                        = "Linux"
      https_only                                     = true
      service_plan_resource_id                       = module.avm-res-web-serverfarm["plan1"].resource_id
      storage_account_name                           = module.avm-res-storage-storageaccount["st1"].name
      public_network_access_enabled                  = false
      enable_application_insights                    = false
      virtual_network_subnet_id                      = try(local.subnet_ids["vnet1_manual.snet2"], null)
      ftp_publish_basic_authentication_enabled       = false
      webdeploy_publish_basic_authentication_enabled = false
      user_assigned_identity_keys                    = ["function"]
      enable_telemetry                               = false
      site_config = {
        always_on        = false
        app_insights_key = "app_insights1"
        application_stack = {
          java = { java_version = "21" }
        }
      }
      app_settings = {
        FUNCTIONS_WORKER_RUNTIME = "java"
        JAVA_VERSION             = "21"
        # Add more app settings as needed
      }
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }
    }
  }
}
#--------------------------------------------------------------------
# App Service Plan configurations
#--------------------------------------------------------------------
locals {
  app_service_plan = {
    plan1 = {
      name                = "infy-claims-functions-plan"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      sku_name            = "P1v2"
      os_type             = "Linux"
      enable_telemetry    = false
      tags = {
        environment = "testing"
        created_by  = "terraform"
      }
    }
  }
}

#--------------------------------------------------------------------
# AML Workspace Configurations
#--------------------------------------------------------------------
locals {
  aml_workspace = {
    aml1 = {
      name                          = "mlw01-claims-test"
      location                      = data.azurerm_resource_group.rg.location
      resource_group_name           = data.azurerm_resource_group.rg.name
      enable_telemetry              = false
      public_network_access_enabled = false
      application_insights_key      = "app_insights1"
      key_vault_key                 = "kv2"
      storage_account_key           = "st1"
      workspace_managed_network = {
        isolation_mode = "AllowOnlyApprovedOutbound"
        firewall_sku   = "Basic"
      }
      managed_identities = {
        system_assigned = true
      }
      private_endpoints = {
        amlpe = {
          name                          = "pe-mlw01-claims-test"
          vnet_key                      = "vnet1_manual"
          subnet_key                    = "snet1"
          subresource_name              = "blob"
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        amldiag = {
          name                  = "diag-mlw01-claims-test"
          workspace_resource_id = try(module.law[0].resource_id, null) # if you have LA workspace
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
  }
}

#--------------------------------------------------------------------
# User Assigned Identity configurations
#--------------------------------------------------------------------
locals {
  user_assigned_identities = {
    function = {
      name                = "infy-claims-function-identity"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
    }
  }
}
#--------------------------------------------------------------------
# Application Insights configurations
#--------------------------------------------------------------------
locals {
  app_insights_configs = {
    app_insights1 = {
      name                = "infy-test-appinsights"
      location            = data.azurerm_resource_group.rg.location
      resource_group_name = data.azurerm_resource_group.rg.name
      workspace_id        = module.law[0].resource_id
      tags = {
        created_by = "terraform"
      }
    }
  }
}
#--------------------------------------------------------------------
# Cognitive Services Account configuration
#--------------------------------------------------------------------
locals {
  cognitiveservices = {
    #----------------------------------------------------------------
    # Document Intelligence
    #----------------------------------------------------------------
    di1 = {
      enable_account = true
      name      = "di-claims-test-001"
      parent_id = data.azurerm_resource_group.rg.id
      location  = data.azurerm_resource_group.rg.location
      sku_name  = "S0"
      kind      = "FormRecognizer"
      enable_telemetry = false
      local_auth_enabled = false
      public_network_access_enabled = false
      private_endpoints = {
        di_pe = {
          name       = "pvt-endpoint-di-claims-test-poc"
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
          # If you already have private DNS zone ids, place them here; otherwise keep empty.
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        di_diag = {
          name                  = "diag-di-claims-test-001"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
    #----------------------------------------------------------------
    # Azure Open AI
    #----------------------------------------------------------------
    openai = {
      enable_account = true
      name      = "cind-oai-claims-test12"
      parent_id = data.azurerm_resource_group.rg.id
      location  = "South India"
      sku_name  = "S0"
      kind      = "OpenAI"
      enable_telemetry = false
      local_auth_enabled = false
      public_network_access_enabled = false
      private_endpoints = {
        openai_pe = {
          name       = "pvt-endpoint-cind-oai-claims-test12"
          vnet_key   = "vnet1_manual"
          subnet_key = "snet1"
          location   = data.azurerm_resource_group.rg.location
          # If you already have private DNS zone ids, place them here; otherwise keep empty.
          private_dns_zone_resource_ids = []
        }
      }
      diagnostic_settings = {
        openai_diag = {
          name                  = "diag-cind-oai-claims-test12"
          workspace_resource_id = try(module.law[0].resource_id, null)
        }
      }
      tags = {
        created_by = "terraform"
      }
    }
  }
}