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

resource "azurerm_key_vault_secret" "servicebus-dapr" {
  name         = "servicebus-dapr-connection"
  value        = azurerm_servicebus_namespace_authorization_rule.demo.primary_connection_string
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "cosmos-key" {
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.demo.primary_master_key
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "blob-key" {
  name         = "blob-key"
  value        = azurerm_storage_account.demo.primary_access_key
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

