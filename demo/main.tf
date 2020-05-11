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
  version = "=2.9.0"
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
  location = "westeurope"
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

resource "azurerm_application_insights" "dapr" {
  name                = "appin-dapr-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_monitor_diagnostic_setting" "aks-diag" {
  name                       = "aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.demo.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id

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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id

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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id

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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id

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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.demo.id

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

resource "azurerm_subnet" "nginx" {
  name                 = "nginx"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "k3s" {
  name                 = "k3s"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefix       = "10.0.2.0/24"
}

# resource "azurerm_subnet" "aci" {
#   name                 = "aci"
#   resource_group_name  = azurerm_resource_group.demo.name
#   virtual_network_name = azurerm_virtual_network.demo.name
#   address_prefix       = "10.0.3.0/24"

#   delegation {
#     name = "aciDelegation"
#     service_delegation {
#       name    = "Microsoft.ContainerInstance/containerGroups"
#       actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
#     }
#   }
# }

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
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
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
    name         = "nginx"
    ip_addresses = ["10.0.1.100"]
  }

  backend_http_settings {
    name                  = "http"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    probe_name            = "nginx-default"
  }

  http_listener {
    name                           = "nginx-listener"
    frontend_ip_configuration_name = "my-frontend-ip-configuration"
    frontend_port_name             = "web"
    protocol                       = "Http"
    host_name                      = "linkerd.nginx.cloud.tomaskubica.in"
  }

  probe {
    name                = "nginx-default"
    host                = "linkerd.nginx.cloud.tomaskubica.in"
    interval            = 5
    protocol            = "Http"
    path                = "/"
    timeout             = 5
    unhealthy_threshold = 2
    match {
      status_code = ["200", "401", "404"]
    }
  }

  request_routing_rule {
    name                       = "nginx-rule"
    rule_type                  = "Basic"
    http_listener_name         = "nginx-listener"
    backend_address_pool_name  = "nginx"
    backend_http_settings_name = "http"
  }
}

# Kubernetes
resource "azurerm_kubernetes_cluster" "demo" {
  name                = "aks-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "aks-${var.env}-${random_string.prefix.result}"
  node_resource_group = "${azurerm_resource_group.demo.name}-aksresources"

  default_node_pool {
    name                = "default"
    vm_size             = "Standard_B2ms"
    enable_auto_scaling = true
    max_count           = 6
    min_count           = 2
    availability_zones  = [1, 2, 3]
    vnet_subnet_id      = azurerm_subnet.aks.id
    max_pods            = 100
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
    # aci_connector_linux {
    #   enabled     = true
    #   subnet_name = "aci"
    # }
  }
}

resource "azurerm_devspace_controller" "demo" {
  name                = "acctestdsc1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  sku_name = "S1"

  target_container_host_resource_id        = "${azurerm_kubernetes_cluster.demo.id}"
  target_container_host_credentials_base64 = "${base64encode(azurerm_kubernetes_cluster.demo.kube_admin_config_raw)}"
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

# K3s
resource "azurerm_network_interface" "k3s" {
  name                = "k3s-nic"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k3s.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.100"
  }
}

resource "azurerm_linux_virtual_machine" "k3s" {
  name                = "k3s"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  size                = "Standard_B2s"
  admin_username      = "tomas"
  network_interface_ids = [
    azurerm_network_interface.k3s.id,
  ]

  admin_ssh_key {
    username   = "tomas"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFhm1FUhzt/9roX7SmT/dI+vkpyQVZp3Oo5HC23YkUVtpmTdHje5oBV0LMLBB1Q5oSNMCWiJpdfD4VxURC31yet4mQxX2DFYz8oEUh0Vpv+9YWwkEhyDy4AVmVKVoISo5rAsl3JLbcOkSqSO8FaEfO5KIIeJXB6yGI3UQOoL1owMR9STEnI2TGPZzvk/BdRE73gJxqqY0joyPSWOMAQ75Xr9ddWHul+v//hKjibFuQF9AFzaEwNbW5HxDsQj8gvdG/5d6mt66SfaY+UWkKldM4vRiZ1w11WlyxRJn5yZNTeOxIYU4WLrDtvlBklCMgB7oF0QfiqahauOEo6m5Di2Ex"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "k3s" {
  name                 = "k3s"
  virtual_machine_id   = azurerm_linux_virtual_machine.k3s.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/tkubica12/kubernetes-demo/master/demo/scripts/azuremonitor-k3s-install.sh"]
    }
SETTINGS

  protected_settings = <<PROTECTEDSETTINGS
    {
        "commandToExecute": "./azuremonitor-k3s-install.sh ${azurerm_log_analytics_workspace.demo.workspace_id} ${azurerm_log_analytics_workspace.demo.primary_shared_key}"
    }
PROTECTEDSETTINGS

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
    consistency_level       = "Session"
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
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "demo" {
  name                = "statecont"
  resource_group_name = azurerm_resource_group.demo.name
  account_name        = azurerm_cosmosdb_account.demo.name
  database_name       = azurerm_cosmosdb_sql_database.demo.name
  partition_key_path  = "/id"
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

# Managed identities and RBAC
## Identity for FlexVolume
resource "azurerm_user_assigned_identity" "secretsReader" {
  name                = "secretsReader"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

## Identity for KEDA
resource "azurerm_user_assigned_identity" "keda" {
  name                = "keda"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

## Identity for Application Gateway ingress controller
resource "azurerm_user_assigned_identity" "ingress" {
  name                = "ingressContributor"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

## AKS identity to access ACR
resource "azurerm_role_assignment" "aks" {
  scope                = azurerm_container_registry.demo.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
}

resource "azurerm_role_assignment" "akskubelet" {
  scope                = azurerm_container_registry.demo.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

## AKS identity to access VNET
resource "azurerm_role_assignment" "aks-network" {
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
}

## AKS-kubelet identity for AAD Pod Identity solution
resource "azurerm_role_assignment" "kubelet-mainrg-vmcontributor" {
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "kubelet-mainrg-identityoperator" {
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

data "azurerm_resource_group" "aksresources-rg" {
  name = azurerm_kubernetes_cluster.demo.node_resource_group
}

resource "azurerm_role_assignment" "kubelet-resourcesrg-vmcontributor" {
  scope                = data.azurerm_resource_group.aksresources-rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "kubelet-resourcesrg-identityoperator" {
  scope                = data.azurerm_resource_group.aksresources-rg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

## Application Gateway ingress identity to access Application Gateway
resource "azurerm_role_assignment" "ingress" {
  scope                = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.ingress.principal_id
}

## KEDA - Service Bus reader
resource "azurerm_role_assignment" "keda-servicebus" {
  scope                = azurerm_servicebus_namespace.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.keda.principal_id
}

## Get id of Azure Policy identity
data "azurerm_user_assigned_identity" "azurepolicy" {
  name                = "azurepolicy-aks-${var.env}-${random_string.prefix.result}"
  resource_group_name = data.azurerm_resource_group.aksresources-rg.name
}

# Azure Policy
locals {
  excludedNamespaces = <<PARAMETERS
{
  "excludedNamespaces": {
    "value": [ 
      "kube-system",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows"
      ]
  }
}
PARAMETERS
}

resource "azurerm_policy_assignment" "kube-no-privileged" {
  name                 = "kube-no-privileged"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - do not allow privileged containers"

  parameters = local.excludedNamespaces
}

resource "azurerm_policy_assignment" "kube-https-ingress" {
  name                 = "kube-https-ingress"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - enforce HTTPS on Ingress"

  parameters = local.excludedNamespaces
}

resource "azurerm_policy_assignment" "kube-no-public-lb" {
  name                 = "kube-no-public-lb"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - no Public IP on Load Balancer"

  parameters = local.excludedNamespaces
}

resource "azurerm_policy_assignment" "kube-resource-limits" {
  name                 = "kube-resource-limits"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - resource limits must be specified and no more than ..."

  parameters = <<PARAMETERS
{
  "cpuLimit": {
    "value": "200m"
  },
  "memoryLimit": {
    "value": "128Mi"
  },
  "excludedNamespaces": {
    "value": [ 
      "kube-system",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows"
      ]
  }
}
PARAMETERS
}

resource "azurerm_policy_assignment" "kube-mandatory-labels" {
  name                 = "kube-mandatory-labels"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/46592696-4c7b-4bf3-9e45-6c2763bdc0a6"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - label release-type is mandatory"

  parameters = <<PARAMETERS
{
    "labelsList": {
    "value": [
      "release-type"
    ]
  },
  "excludedNamespaces": {
    "value": [ 
      "kube-system",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows"
      ]
  }
}
PARAMETERS
}

resource "azurerm_policy_assignment" "kube-only-acr" {
  name                 = "kube-only-acr"
  scope                = azurerm_resource_group.demo.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469"
  description          = "Exceptions for some namespaces"
  display_name         = "Kubernetes - allo only impages from ACR"

  parameters = <<PARAMETERS
{
  "allowedContainerImagesRegex": {
    "value": ".*azurecr.io"
  },
  "excludedNamespaces": {
    "value": [ 
      "kube-system",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows"
      ]
  }
}
PARAMETERS
}
