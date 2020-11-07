resource "azurerm_template_deployment" "demo" {
  name                = "apim-gateway-deploy"
  resource_group_name = azurerm_resource_group.demo.name
  deployment_mode     = "Incremental"
  parameters = {
    "apimName" = "apim-${var.env}-${random_string.prefix.result}"
  }

  template_body = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "apimName": {
            "type": "String"
        }
  },
  "variables": {},
  "resources": [
     {
            "type": "Microsoft.ApiManagement/service",
            "apiVersion": "2019-12-01",
            "name": "[parameters('apimName')]",
            "location": "North Europe",
            "sku": {
                "name": "Developer",
                "capacity": 1
            },
            "properties": {
                "publisherEmail": "tomasdemo@tomas.demo",
                "publisherName": "Tomas Demo",
                "notificationSenderEmail": "apimgmt-noreply@mail.windowsazure.com"
            }
        },
        {
            "type": "Microsoft.ApiManagement/service/gateways",
            "apiVersion": "2019-12-01",
            "name": "[concat(parameters('apimName'), '/myLocalGateway')]",
            "properties": {
                "locationData": {
                    "name": "Prague"
                }
            }
        },
        {
          "type": "Microsoft.ApiManagement/service/apis",
          "apiVersion": "2019-12-01",
          "name": "[concat(parameters('apimName'), '/podinfo')]",
          "dependsOn": [
              "[resourceId('Microsoft.ApiManagement/service', parameters('apimName'))]"
          ],
          "properties": {
              "displayName": "podinfo",
              "apiRevision": "1",
              "subscriptionRequired": false,
              "serviceUrl": "http://podinfo",
              "path": "podinfo",
              "protocols": [
                  "http"
              ],
              "isCurrent": true
          }
      },
      {
        "type": "Microsoft.ApiManagement/service/gateways/apis",
        "apiVersion": "2019-12-01",
        "name": "[concat(parameters('apimName'), '/myLocalGateway/podinfo')]",
        "dependsOn": [
            "[resourceId('Microsoft.ApiManagement/service/gateways', parameters('apimName'), 'myLocalGateway')]",
            "[resourceId('Microsoft.ApiManagement/service/apis', parameters('apimName'), 'podinfo')]",
            "[resourceId('Microsoft.ApiManagement/service', parameters('apimName'))]"
        ],
        "properties": {}
      },
      {
        "type": "Microsoft.ApiManagement/service/apis/operations",
        "apiVersion": "2019-12-01",
        "name": "[concat(parameters('apimName'), '/podinfo/version')]",
        "dependsOn": [
            "[resourceId('Microsoft.ApiManagement/service/apis', parameters('apimName'), 'podinfo')]",
            "[resourceId('Microsoft.ApiManagement/service', parameters('apimName'))]"
        ],
        "properties": {
            "displayName": "version",
            "method": "GET",
            "urlTemplate": "/version",
            "templateParameters": [],
            "responses": [
                {
                    "statusCode": 200,
                    "description": "Returns version information",
                    "representations": [
                        {
                            "contentType": "application/json",
                            "sample": "{\r\n  \"commit\": \"TASJDGX54\",\r\n  \"version\": \"1.2.3\"\r\n}"
                        }
                    ],
                    "headers": []
                }
            ]
        }
      },
      {
        "type": "Microsoft.ApiManagement/service/apis/operations/policies",
        "apiVersion": "2019-12-01",
        "name": "[concat(parameters('apimName'), '/podinfo/version/policy')]",
        "dependsOn": [
            "[resourceId('Microsoft.ApiManagement/service/apis/operations', parameters('apimName'), 'podinfo', 'version')]",
            "[resourceId('Microsoft.ApiManagement/service/apis', parameters('apimName'), 'podinfo')]",
            "[resourceId('Microsoft.ApiManagement/service', parameters('apimName'))]"
        ],
        "properties": {
            "value": "<!--\r\n    IMPORTANT:\r\n    - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.\r\n    - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.\r\n    - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.\r\n    - To add a policy, place the cursor at the desired insertion point and select a policy from the sidebar.\r\n    - To remove a policy, delete the corresponding policy statement from the policy document.\r\n    - Position the <base> element within a section element to inherit all policies from the corresponding section element in the enclosing scope.\r\n    - Remove the <base> element to prevent inheriting policies from the corresponding section element in the enclosing scope.\r\n    - Policies are applied in the order of their appearance, from the top down.\r\n    - Comments within policy elements are not supported and may disappear. Place your comments between policy elements or at a higher level scope.\r\n-->\r\n<policies>\r\n  <inbound>\r\n    <base />\r\n    <mock-response status-code=\"200\" content-type=\"application/json\" />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>",
            "format": "xml"
        }
      }
  ],
  "outputs": {
    "gatewayId": {
      "type": "string",
      "value": "[resourceId('Microsoft.ApiManagement/service/gateways', parameters('apimName'), 'myLocalGateway')]"
    },
    "apim_id": {
      "type": "string",
      "value": "[resourceId('Microsoft.ApiManagement/service', parameters('apimName'))]"
    },
    "apim_mgmt_url": {
      "type": "string",
      "value": "[reference(resourceId('Microsoft.ApiManagement/service', parameters('apimName'))).managementApiUrl]"
    }
}
}
TEMPLATE
}

