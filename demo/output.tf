output "kube_admin_config" {
  value = azurerm_kubernetes_cluster.demo.kube_admin_config_raw
}

output "kube_name" {
  value = azurerm_kubernetes_cluster.demo.name
}

output "gw_name" {
  value = azurerm_application_gateway.appgw.name
}

output "storage_account" {
  value = azurerm_storage_account.demo.name
}

output "storage_key" {
  value = azurerm_storage_account.demo.primary_access_key
}

output "servicebus_dapr_connection" {
  value = azurerm_servicebus_namespace_authorization_rule.demo.primary_connection_string
}

output "servicebus_todo_connection" {
  value = azurerm_servicebus_queue_authorization_rule.myapptodo.primary_connection_string
}

output "eventhub_connection" {
  value = azurerm_eventhub_authorization_rule.demo.primary_connection_string
}

output "redis_host" {
  value = "${azurerm_redis_cache.demo.hostname}:${azurerm_redis_cache.demo.ssl_port}"
}

output "redis_password" {
  value = azurerm_redis_cache.demo.primary_access_key
}



# output "cosmosdb_key" {
#   value = azurerm_cosmosdb_account.demo.primary_master_key
# }

# output "cosmosdb_url" {
#   value = azurerm_cosmosdb_account.demo.endpoint
# }

output "resource_group" {
  value = azurerm_resource_group.demo.name
}

output "appgw_name" {
  value = azurerm_application_gateway.appgw.name
}

output "registry_name" {
  value = azurerm_container_registry.demo.name
}

output "psql_name" {
  value = azurerm_postgresql_server.demo.name
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.demo.workspace_id
}

output "secretsReader_resourceId" {
  value = azurerm_user_assigned_identity.secretsReader.id
}

output "secretsReader_clientId" {
  value = azurerm_user_assigned_identity.secretsReader.client_id
}

output "keda_resourceId" {
  value = azurerm_user_assigned_identity.keda.id
}

output "keda_clientId" {
  value = azurerm_user_assigned_identity.keda.client_id
}

output "keyvault_name" {
  value = azurerm_key_vault.demo.name
}

output "keyvault_tenantid" {
  value = azurerm_key_vault.demo.tenant_id
}

output "keyvault_psql_keyname" {
  value = azurerm_key_vault_secret.psql.name
}

output "appin_key" {
  value = azurerm_application_insights.demo.instrumentation_key
}

output "appin_id" {
  value = azurerm_application_insights.demo.app_id
}

output "ingressContributor_client_id" {
  value = azurerm_user_assigned_identity.ingress.client_id
}

output "ingressContributor_resource_id" {
  value = azurerm_user_assigned_identity.ingress.id
}


