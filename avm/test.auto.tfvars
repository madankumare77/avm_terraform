# ───────────────────────────────────────────────────────────────
#  NETWORKING COMPONENTS
# ───────────────────────────────────────────────────────────────
enable_virtual_networks = true # Creates Virtual Network(s) defined in locals/variables
enable_nsg              = false # Creates Network Security Groups (NSGs)

# ───────────────────────────────────────────────────────────────
#  STORAGE ACCOUNT
# ───────────────────────────────────────────────────────────────
enable_storage_account = true # Creates Storage Accounts (Blob/File/Queue etc.)

# ───────────────────────────────────────────────────────────────
#  MONITORING
# ───────────────────────────────────────────────────────────────
enable_log_analytics_workspace = true #Creates a Log Analytics workspace
enable_application_insights             = true # Creates an Application Insights instance

# ───────────────────────────────────────────────────────────────
#  SECURITY AND IDENTITY
# ───────────────────────────────────────────────────────────────
enable_kv                 = true # Creates Azure Key Vault
enable_user_assigned_identities = false # Creates User Assigned Managed Identity (UAMI)

# ───────────────────────────────────────────────────────────────
#  APPLICATION PLATFORM RESOURCES
# ───────────────────────────────────────────────────────────────
enable_function_app     = false # Creates Azure Function App (Linux/Windows — based on module config)
enable_app_service_plan = true  # Creates App Service Plan (Linux/Windows — based on module config)
enable_aml_workspace    = false # Creates Azure Machine Learning workspace
enable_cognitiveservices = true  # Creates Azure Cognitive Services account (Document Inteligent and Azure OpenAI)
