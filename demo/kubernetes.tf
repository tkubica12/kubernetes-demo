# Kubernetes
resource "azurerm_kubernetes_cluster" "demo" {
  name                = "aks-${var.env}-${random_string.prefix.result}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "aks-${var.env}-${random_string.prefix.result}"
  node_resource_group = "${azurerm_resource_group.demo.name}-aksresources"
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
  default_node_pool {
    name                = "default"
    vm_size             = "Standard_B4ms"
    enable_auto_scaling = true
    max_count           = 15
    min_count           = 3
    node_count          = 3
    availability_zones  = [1]
    vnet_subnet_id      = azurerm_subnet.aks.id
    max_pods            = 100
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    load_balancer_sku  = "standard"
    dns_service_ip     = "192.168.0.10"
    service_cidr       = "192.168.0.0/22"
    docker_bridge_cidr = "192.168.10.1/24"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      admin_group_object_ids = [var.admin_group_id]
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

# resource "azurerm_devspace_controller" "demo" {
#   name                = "acctestdsc1"
#   location            = azurerm_resource_group.demo.location
#   resource_group_name = azurerm_resource_group.demo.name

#   sku_name = "S1"

#   target_container_host_resource_id        = "${azurerm_kubernetes_cluster.demo.id}"
#   target_container_host_credentials_base64 = "${base64encode(azurerm_kubernetes_cluster.demo.kube_admin_config_raw)}"
# }

resource "azurerm_kubernetes_cluster_node_pool" "demo" {
  name                  = "wokna"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = "Standard_B2s"
  node_count            = 1
  availability_zones    = [1, 2, 3]
  os_type               = "Windows"
  node_taints           = ["os=windows:NoSchedule"]
  vnet_subnet_id        = azurerm_subnet.aks.id
}

resource "azurerm_kubernetes_cluster_node_pool" "acrdata" {
  name                  = "hapool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = "Standard_B2s"
  node_count            = 3
  availability_zones    = [1, 2, 3]
  node_labels           = {"ha" : "zones" }
  node_taints           = ["ha=zones:NoSchedule"]
  vnet_subnet_id        = azurerm_subnet.aks.id
}

# Container registry
resource "azurerm_container_registry" "demo" {
  name                     = "registry${var.env}${random_string.prefix.result}"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["West Europe"]
}
