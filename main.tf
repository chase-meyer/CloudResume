# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.1"
    }
  }

  required_version = ">= 1.1.0"
}

# using environmental variables
variable "my_ip" {}
variable "storage_acct" {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "prod" {
  name     = "resume-resources"
  location = "centralus"
}

resource "azurerm_resource_group" "dom" {
  name     = "domain-resources"
  location = "centralus"
}

resource "azurerm_storage_account" "prod" {
  name                     = var.storage_acct
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = azurerm_resource_group.prod.location
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

resource "azurerm_cdn_profile" "prod" {
  name                = "resume-cdn-profile"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  sku                 = "Standard_Verizon"
}

resource "azurerm_cdn_endpoint" "prod" {
  name                = "resume-endpoint"
  profile_name        = azurerm_cdn_profile.prod.name
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name

  origin {
    name      = "prod"
    host_name = azurerm_storage_account.prod.primary_web_host
  }
}

resource "azurerm_dns_zone" "prod" {
  name                = "chase-meyer.space"
  resource_group_name = azurerm_resource_group.dom.name
}

resource "azurerm_dns_cname_record" "prod" {
  name                = "resume"
  zone_name           = resource.azurerm_dns_zone.prod.name
  resource_group_name = resource.azurerm_dns_zone.prod.resource_group_name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.prod.id
}

resource "azurerm_cdn_endpoint_custom_domain" "prod" {
  name            = "resume-domain"
  cdn_endpoint_id = azurerm_cdn_endpoint.prod.id
  host_name       = "${azurerm_dns_cname_record.prod.name}.${resource.azurerm_dns_zone.prod.name}"
  cdn_managed_https
}