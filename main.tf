# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
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
    default_action = "Deny"
    ip_rules       = [var.my_ip]
  }
}