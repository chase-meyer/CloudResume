# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.1"
    }
  }

  required_version = ">= 1.9.0"
}

# Using environmental variables
variable "storage_acct" {}

variable "cosmos_db_endpoint" {
  description = "The endpoint URI of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_key" {
  description = "The primary key of the Cosmos DB account"
  type        = string
}

variable "api_key" {
  description = "The API key for the Function App"
  type        = string
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Add resource group for resume objects
resource "azurerm_resource_group" "resume-rg" {
  name     = "resume-resources"
  location = "centralus"
}

# Add resource group for domain
resource "azurerm_resource_group" "dom-rg" {
  name     = "domain-resources"
  location = "centralus"
}

# Storage account and static website for resume
resource "azurerm_storage_account" "this" {
  name                     = var.storage_acct
  resource_group_name      = azurerm_resource_group.resume-rg.name
  location                 = azurerm_resource_group.resume-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  static_website {
    index_document     = "Resume.html"
    error_404_document = "404.html"
  }

  network_rules {
    default_action = "Allow"
  }
}

# CDN profile for resume using Standard_Microsoft tier
resource "azurerm_cdn_profile" "this" {
  name                = "resume-cdn-profile"
  location            = azurerm_resource_group.resume-rg.location
  resource_group_name = azurerm_resource_group.resume-rg.name
  sku                 = "Standard_Microsoft"
}

# Connect CDN to static website on the storage account
resource "azurerm_cdn_endpoint" "this" {
  name                = "resume-endpoint"
  profile_name        = azurerm_cdn_profile.this.name
  location            = azurerm_resource_group.resume-rg.location
  resource_group_name = azurerm_resource_group.resume-rg.name

  origin {
    name      = "this"
    host_name = azurerm_storage_account.this.primary_web_host
  }

  origin_host_header = azurerm_storage_account.this.primary_web_host
}

# DNS zone for my domain
resource "azurerm_dns_zone" "this" {
  name                = "chase-meyer.space"
  resource_group_name = azurerm_resource_group.dom-rg.name
}

# CNAME record resume.chase-meyer.space pointing to CDN endpoint
resource "azurerm_dns_cname_record" "resume-cname" {
  name                = "resume"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.this.id
}

# Assign CDN a custom domain and give it a managed HTTPS so Azure auto supplies SSL cert
resource "azurerm_cdn_endpoint_custom_domain" "this" {
  name            = "resume-domain"
  cdn_endpoint_id = azurerm_cdn_endpoint.this.id
  host_name       = "${azurerm_dns_cname_record.resume-cname.name}.${azurerm_dns_zone.this.name}"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

# Random integer to use in naming cosmosdb_account
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# CosmosDB account with table and serverless capacity and failover location westus3
resource "azurerm_cosmosdb_account" "this" {
  name                = "resume-cosmos-db-${random_integer.ri.result}"
  location            = azurerm_resource_group.resume-rg.location
  resource_group_name = azurerm_resource_group.resume-rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  capabilities {
    name = "EnableTable"
  }

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Eventual"
  }

  geo_location {
    location          = "westus3"
    failover_priority = 0
  }
}

# CosmosDB table for storing resume data
resource "azurerm_cosmosdb_table" "this" {
  name                = "resume-cosmos-table"
  resource_group_name = azurerm_resource_group.resume-rg.name
  account_name        = azurerm_cosmosdb_account.this.name
}

# azurerm_service_plan for Linux function app 
resource "azurerm_service_plan" "this" {
  name                = "service-plan-resume"
  resource_group_name = azurerm_resource_group.resume-rg.name
  location            = azurerm_resource_group.resume-rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_application_insights" "this" {
  name                = "application-insights-resume"
  location            = azurerm_resource_group.resume-rg.location
  resource_group_name = azurerm_resource_group.resume-rg.name
  application_type    = "other"
}

resource "azurerm_linux_function_app" "this" {
  name                = "chase-meyer-resume-api"
  resource_group_name = azurerm_resource_group.resume-rg.name
  location            = azurerm_resource_group.resume-rg.location

  service_plan_id            = azurerm_service_plan.this.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key

  site_config {
    application_insights_key               = azurerm_application_insights.this.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.this.connection_string
    application_stack {
      python_version = 3.11 #FUNCTIONS_WORKER_RUNTIME        
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.this.instrumentation_key}"
    "COSMOS_DB_ENDPOINT"             = var.cosmos_db_endpoint
    "COSMOS_DB_KEY"                  = var.cosmos_db_key
    "API_KEY"                        = var.api_key
  }
}

# CNAME record resume-functions.chase-meyer.space pointing to Azure Function App
resource "azurerm_dns_cname_record" "resume-functions-cname" {
  name                = "resume-functions"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = 3600
  record              = azurerm_linux_function_app.this.default_hostname
}

# TXT record asuid.resume-functions.chase-meyer.space for Azure Function App
resource "azurerm_dns_txt_record" "resume-functions-txt" {
  name                = "asuid.resume-functions"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = 3600

  record {
    value = "FEBFBCB5250DFBF9BB75D782499872A15EF7126A1D096F4A949E4E1490BDA687"
  }
}

output "resource_group_resume_id" {
  value = azurerm_resource_group.resume-rg.id
}

output "resource_group_dom_id" {
  value = azurerm_resource_group.dom-rg.id
}

output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "cdn_profile_id" {
  value = azurerm_cdn_profile.this.id
}

output "cdn_endpoint_id" {
  value = azurerm_cdn_endpoint.this.id
}

output "app_id" {
  value = azurerm_application_insights.this.id
}

output "instrumentation_key" {
  value     = azurerm_application_insights.this.instrumentation_key
  sensitive = true
}

output "service_plan_id" {
  value = azurerm_service_plan.this.id
}

output "linux_function_app_id" {
  value = azurerm_linux_function_app.this.id
}