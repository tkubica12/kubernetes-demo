terraform destroy -auto-approve \
    -target  azurerm_monitor_diagnostic_setting.aks-diag \
    -target  azurerm_monitor_diagnostic_setting.psql-diag \
    -target  azurerm_monitor_diagnostic_setting.servicebus-diag \
    -target  azurerm_monitor_diagnostic_setting.appgw-diag \
    -target  azurerm_monitor_diagnostic_setting.keyvault-diag \
    -target  azurerm_policy_assignment.kube-no-privileged-diag \
    -target  azurerm_policy_assignment.kube-https-ingress \
    -target  azurerm_policy_assignment.kube-no-public-lb \
    -target  azurerm_policy_assignment.kube-resource-limits \
    -target  azurerm_policy_assignment.kube-mandatory-labels \
    -target  azurerm_policy_assignment.kube-only-acr
az group delete -n cloudnative-demo -y --no-wait