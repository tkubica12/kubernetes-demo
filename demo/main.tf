variable "env" {
  default = "demo"
}

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "psql_password" {}
variable "client_app_id" {}
variable "server_app_id" {}
variable "server_app_secret" {}
variable "tenant_app_id" {}
variable "admin_group_id" {}

# Configure the Azure and AAD provider
provider "azurerm" {
  version = "=2.33.0"
  features {}
}

# Store state in Azure Blob Storage
terraform {
  backend "azurerm" {
    resource_group_name  = "shared-services"
    storage_account_name = "tomuvstore"
    container_name       = "tstate-cloudnative"
    key                  = "terraform.tfstate"
  }
}

# Pseudorandom prefix
resource "random_string" "prefix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  number  = true
}

data "azurerm_client_config" "current" {
}

# Resource Group
resource "azurerm_resource_group" "demo" {
  name     = "cloudnative-${var.env}"
  location = "northeurope"
}



