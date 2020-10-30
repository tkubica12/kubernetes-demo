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
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "nginx" {
  name                 = "nginx"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "k3s" {
  name                 = "k3s"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.2.0/24"]
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