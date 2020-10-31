# Azure Monitor
resource "azurerm_log_analytics_workspace" "demo" {
  name                = "logs-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_workspace" "audit" {
  name                = "auditlogs-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "Free"
}

resource "azurerm_log_analytics_workspace" "arc" {
  name                = "arc-${var.env}-${random_string.prefix.result}"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "PerGB2018"
}

resource "azurerm_application_insights" "demo" {
  name                = "appin-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_application_insights" "dapr" {
  name                = "appin-dapr-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_application_insights" "linkerd" {
  name                = "appin-linkerd-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_application_insights" "opentelemetry" {
  name                = "appin-opentelemetry-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_monitor_diagnostic_setting" "aks-diag" {
  name                       = "aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.demo.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  log {
    category = "kube-apiserver"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-audit"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-controller-manager"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "kube-scheduler"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "cluster-autoscaler"
    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "psql-diag" {
  name                       = "psql-diag"
  target_resource_id         = azurerm_postgresql_server.demo.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  log {
    category = "PostgreSQLLogs"
    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "keyvault-diag" {
  name                       = "keyvault-diag"
  target_resource_id         = azurerm_key_vault.demo.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  log {
    category = "AuditEvent"
    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "servicebus-diag" {
  name                       = "servicebus-diag"
  target_resource_id         = azurerm_servicebus_namespace.demo.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  log {
    category = "OperationalLogs"
    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw-diag" {
  name                       = "appgw-diag"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  log {
    category = "ApplicationGatewayAccessLog"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "ApplicationGatewayPerformanceLog"
    retention_policy {
      enabled = false
    }
  }

  log {
    category = "ApplicationGatewayFirewallLog"
    retention_policy {
      enabled = false
    }
  }
}