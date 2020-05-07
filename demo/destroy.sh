terraform destroy -auto-approve \
    -target  azurerm_monitor_diagnostic_setting.aks-diag \
    -target  azurerm_monitor_diagnostic_setting.psql-diag \
    -target  azurerm_monitor_diagnostic_setting.servicebus-diag \
    -target  azurerm_monitor_diagnostic_setting.appgw-diag \
    -target  azurerm_monitor_diagnostic_setting.keyvault-diag
az group delete -n cloudnative-demo -y --no-wait