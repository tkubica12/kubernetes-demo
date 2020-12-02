# Azure Policy
locals {
  excludedNamespaces = <<PARAMETERS
{
  "excludedNamespaces": {
    "value": [ 
      "kube-system",
      "azds",
      "gatekeeper-system",
      "aadpodidentity",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio-system",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows",
      "intro",
      "arc",
      "sql",
      "psql",
      "osm-system",
      "osm-demo",
      "apim"
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
      "azds",
      "gatekeeper-system",
      "aadpodidentity",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio-system",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows",
      "intro",
      "arc",
      "sql",
      "psql",
      "osm-system",
      "osm-demo",
      "apim"
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
      "azds",
      "gatekeeper-system",
      "aadpodidentity",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio-system",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows",
      "intro",
      "arc",
      "sql",
      "psql",
      "osm-system",
      "osm-demo",
      "apim"
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
      "azds",
      "gatekeeper-system",
      "aadpodidentity",
      "default",
      "linkerd",
      "linkerd-demo",
      "istio-system",
      "istio-demo",
      "canary",
      "grafana",
      "ingress",
      "prometheus",
      "keda",
      "kv",
      "dapr",
      "dapr-demo",
      "windows",
      "intro",
      "arc",
      "sql",
      "psql",
      "osm-system",
      "osm-demo",
      "apim"
      ]
  }
}
PARAMETERS
}
