# PostgreSQL
resource "azurerm_postgresql_server" "demo" {
  name                = "psql-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  sku_name = "GP_Gen5_2"

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    auto_grow             = "Enabled"
    geo_redundant_backup  = "Disabled"
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
resource "azurerm_cosmosdb_account" "demo" {
  name                = "cosmos-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  enable_automatic_failover = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.demo.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "demo" {
  name                = "daprdb"
  resource_group_name = azurerm_cosmosdb_account.demo.resource_group_name
  account_name        = azurerm_cosmosdb_account.demo.name
}

resource "azurerm_cosmosdb_sql_container" "demo" {
  name                = "statecont"
  resource_group_name = azurerm_resource_group.demo.name
  account_name        = azurerm_cosmosdb_account.demo.name
  database_name       = azurerm_cosmosdb_sql_database.demo.name
  partition_key_path  = "/id"
  throughput          = 400
}

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

resource "azurerm_servicebus_queue" "binding" {
  name                = "binding"
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