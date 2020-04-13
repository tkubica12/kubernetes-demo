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

# Configure the Azure and AAD provider
provider "azurerm" {
  version = "=2.5.0"
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
  length = 8
  special = false
  lower = true
  upper = false
  number = true
}

data "azurerm_client_config" "current" {
}

# Resource Group
resource "azurerm_resource_group" "demo" {
  name     = "cloudnative-${var.env}"
  location = "centralus"
}

# Azure Monitor
resource "azurerm_log_analytics_workspace" "demo" {
  name                = "logs-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "PerGB2018"
}

resource "azurerm_application_insights" "demo" {
  name                = "appin-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

# Networking
resource "azurerm_virtual_network" "demo" {
  name                = "my-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefix       = "10.0.128.0/21"
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_public_ip" "appgw" {
  name                = "appgwip-${var.env}"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "tomascloudnativedemo${var.env}"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-${var.env}"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "web"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "my-frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "bepool"
  }

  backend_http_settings {
    name                  = "http"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
  }

  http_listener {
    name                           = "httpListener"
    frontend_ip_configuration_name = "my-frontend-ip-configuration"
    frontend_port_name             = "web"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "httpListener"
    backend_address_pool_name  = "bepool"
    backend_http_settings_name = "http"
  }
}

# Kubernetes
resource "azurerm_kubernetes_cluster" "demo" {
  name                = "aks-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "aks-${var.env}-${random_string.prefix.result}"

  default_node_pool {
    name                = "default"
    vm_size             = "Standard_B2s"
    enable_auto_scaling = true
    max_count           = 6
    min_count           = 3
    availability_zones  = [1, 2, 3]
    vnet_subnet_id      = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    dns_service_ip     = "192.168.0.10"
    service_cidr       = "192.168.0.0/22"
    docker_bridge_cidr = "192.168.10.1/24"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      client_app_id     = var.client_app_id
      server_app_id     = var.server_app_id
      server_app_secret = var.server_app_secret
      tenant_id         = var.tenant_app_id
    }
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id
    }
    azure_policy {
      enabled = true
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "demo" {
  name                  = "wokna"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 1
  availability_zones    = [1, 2, 3]
  os_type               = "Windows"
  node_taints           = ["os=windows:NoSchedule"]
  vnet_subnet_id        = azurerm_subnet.aks.id
}

# Container registry
resource "azurerm_container_registry" "demo" {
  name                     = "registry${var.env}${random_string.prefix.result}"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["North Europe"]
}

# PostgreSQL
resource "azurerm_postgresql_server" "demo" {
  name                = "psql-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  sku_name = "GP_Gen5_2"

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 30
    auto_grow             = "Enabled"
    geo_redundant_backup  = "Enabled"
  }

  administrator_login          = "tomas"
  administrator_login_password = var.psql_password
  version                      = "11"
  ssl_enforcement              = "Enabled"
}

resource "azurerm_postgresql_database" "demo" {
  name                = "todo"
  resource_group_name = azurerm_resource_group.demo.name
  server_name         = azurerm_postgresql_server.demo.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "demo" {
  name                = "AzureServices"
  resource_group_name = azurerm_resource_group.demo.name
  server_name         = azurerm_postgresql_server.demo.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Cosmos DB (DAPR demo)
# resource "azurerm_cosmosdb_account" "demo" {
#   name                = "cosmos-${var.env}-${random_string.prefix.result}"
#   location            = azurerm_resource_group.demo.location
#   resource_group_name = azurerm_resource_group.demo.name
#   offer_type          = "Standard"
#   kind                = "GlobalDocumentDB"

#   enable_automatic_failover = false

#   consistency_policy {
#     consistency_level       = "Session"
#   }

#   geo_location {
#     location          = azurerm_resource_group.demo.location
#     failover_priority = 0
#   }
# }

# resource "azurerm_cosmosdb_sql_database" "demo" {
#   name                = "daprdb "
#   resource_group_name = azurerm_cosmosdb_account.demo.resource_group_name
#   account_name        = azurerm_cosmosdb_account.demo.name
#   throughput          = 400
# }

# resource "azurerm_cosmosdb_sql_container" "demo" {
#   name                = "statecont"
#   resource_group_name = azurerm_resource_group.demo.name
#   account_name        = azurerm_cosmosdb_account.demo.name
#   database_name       = azurerm_cosmosdb_sql_database.demo.name
#   partition_key_path  = "/id"
# }

# Service bus
resource "azurerm_servicebus_namespace" "demo" {
  name                = "servicebus-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "demo" {
  name                = "orders"
  resource_group_name = azurerm_resource_group.demo.name
  namespace_name      = azurerm_servicebus_namespace.demo.name

  enable_partitioning = true
}

resource "azurerm_servicebus_namespace_authorization_rule" "demo" {
  name                = "daprauth"
  namespace_name      = azurerm_servicebus_namespace.demo.name
  resource_group_name = azurerm_resource_group.demo.name

  listen = true
  send   = true
  manage = true
}

resource "azurerm_servicebus_queue" "myapptodo" {
  name                = "myapptodo"
  resource_group_name = azurerm_resource_group.demo.name
  namespace_name      = azurerm_servicebus_namespace.demo.name

  enable_partitioning = true
}

resource "azurerm_servicebus_queue_authorization_rule" "myapptodo" {
  name                = "myapptodoauth"
  namespace_name      = azurerm_servicebus_namespace.demo.name
  queue_name          = azurerm_servicebus_queue.myapptodo.name
  resource_group_name = azurerm_resource_group.demo.name

  listen = true
  send   = true
  manage = false
}

# Storage account (DAPR demo)
resource "azurerm_storage_account" "demo" {
  name                     = "store${var.env}${random_string.prefix.result}"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "demo" {
  name                  = "daprcontainer"
  storage_account_name  = azurerm_storage_account.demo.name
  container_access_type = "private"
}

# Event Hub (DAPR demo)
resource "azurerm_eventhub_namespace" "demo" {
  name                = "eventhub-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "Basic"
}

resource "azurerm_eventhub" "demo" {
  name                = "dapreventhub"
  namespace_name      = azurerm_eventhub_namespace.demo.name
  resource_group_name = azurerm_resource_group.demo.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "demo" {
  name                = "daprauth"
  namespace_name      = azurerm_eventhub_namespace.demo.name
  eventhub_name       = azurerm_eventhub.demo.name
  resource_group_name = azurerm_resource_group.demo.name
  listen              = true
  send                = true
  manage              = false
}

# Key Vault
resource "azurerm_key_vault" "demo" {
  name                        = "vault-${var.env}-${random_string.prefix.result}"
  location                    = azurerm_resource_group.demo.location
  resource_group_name         = azurerm_resource_group.demo.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_enabled         = false
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "user" {
  key_vault_id = azurerm_key_vault.demo.id

  tenant_id = var.tenant_id
  object_id = azurerm_user_assigned_identity.secretsReader.principal_id

  key_permissions = [
    "get",
  ]

  secret_permissions = [
    "get",
  ]

  certificate_permissions = [
    "get",
  ]
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.demo.id

  tenant_id = var.tenant_id
  object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
    ]

    secret_permissions = [
      "set",
      "get",
      "delete",
    ]

  certificate_permissions = [
    "get",
    "create",
  ]
}

resource "azurerm_key_vault_secret" "psql" {
  name         = "psql-jdbc"
  value        = "jdbc:postgresql://${azurerm_postgresql_server.demo.fqdn}:5432/todo?user=tomas@${azurerm_postgresql_server.demo.name}&password=${var.psql_password}&ssl=true"
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "servicebus-todo" {
  name         = "servicebus-todo-connection"
  value        = azurerm_servicebus_queue_authorization_rule.myapptodo.primary_connection_string
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

# Managed identities and RBAC
## Identity for FlexVolume
resource "azurerm_user_assigned_identity" "secretsReader" {
  name = "secretsReader"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

## Identity for Application Gateway ingress controller
resource "azurerm_user_assigned_identity" "ingress" {
  name = "ingressContributor"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

## AKS identity to access ACR
resource "azurerm_role_assignment" "aks" {
  scope                = azurerm_container_registry.demo.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
}

## Application Gateway ingress identity to access Application Gateway
resource "azurerm_role_assignment" "ingress" {
  scope                = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.ingress.principal_id
}

## AAD Pod Identity to get access to managed identities
# resource "azurerm_role_assignment" "podidentity-ingress" {
#   scope                = azurerm_user_assigned_identity.ingress.id
#   role_definition_name = "Managed Identity Operator"
#   principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "podidentity-secrets" {
#   scope                = azurerm_user_assigned_identity.secretsReader.id
#   role_definition_name = "Managed Identity Operator"
#   principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
# }

data "azurerm_resources" "aks" {
  type = azurerm_kubernetes_cluster.demo.name
  resource_group_name = azurerm_resource_group.demo.name
}