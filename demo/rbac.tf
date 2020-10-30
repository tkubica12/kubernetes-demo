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
  depends_on           = [azurerm_kubernetes_cluster.demo]
}

resource "azurerm_role_assignment" "kubelet-resourcesrg-vmcontributor" {
  scope                = data.azurerm_resource_group.aksresources-rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.demo]
}

resource "azurerm_role_assignment" "kubelet-resourcesrg-identityoperator" {
  scope                = data.azurerm_resource_group.aksresources-rg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.demo]
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
  depends_on          = [azurerm_kubernetes_cluster.demo]
}

