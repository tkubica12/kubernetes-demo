if [[ $1 =~ "up" ]]
then
  az vm start --ids $(az vm list --query "[].id" -g acs -o tsv) --no-wait
  az vm start --ids $(az vm list --query "[].id" -g mykubeazurenet -o tsv) --no-wait
  az vm start --ids $(az vm list --query "[].id" -g mykubecalico -o tsv) --no-wait
fi
if [[ $1 =~ "down" ]]
then
  az vm deallocate --ids $(az vm list --query "[].id" -g acs -o tsv) --no-wait
  az vm deallocate --ids $(az vm list --query "[].id" -g mykubeazurenet -o tsv) --no-wait
  az vm deallocate --ids $(az vm list --query "[].id" -g mykubecalico -o tsv) --no-wait
fi
if [[ $1 =~ "acs" ]]
then
  if [[ $2 =~ "up" ]]
  then
    az vm start --ids $(az vm list --query "[].id" -g acs -o tsv) --no-wait
  fi
  if [[ $2 =~ "down" ]]
  then
    az vm deallocate --ids $(az vm list --query "[].id" -g acs -o tsv) --no-wait
  fi
fi
if [[ $1 =~ "azurenet" ]]
then
  if [[ $2 =~ "up" ]]
  then
    az vm start --ids $(az vm list --query "[].id" -g mykubeazurenet -o tsv) --no-wait
  fi
  if [[ $2 =~ "down" ]]
  then
    az vm deallocate --ids $(az vm list --query "[].id" -g mykubeazurenet -o tsv) --no-wait
  fi
fi
if [[ $1 =~ "calico" ]]
then
  if [[ $2 =~ "up" ]]
  then
    az vm start --ids $(az vm list --query "[].id" -g mykubecalico -o tsv) --no-wait
  fi
  if [[ $2 =~ "down" ]]
  then
    az vm deallocate --ids $(az vm list --query "[].id" -g mykubecalico -o tsv) --no-wait
  fi
fi
if [[ $1 =~ "aks" ]]
then
  if [[ $2 =~ "up" ]]
  then
    az vm start --ids $(az vm list --query "[].id" -g MC_aks_tomaks_westus2 -o tsv) --no-wait
  fi
  if [[ $2 =~ "down" ]]
  then
    az vm deallocate --ids $(az vm list --query "[].id" -g MC_aks_tomaks_westus2 -o tsv) --no-wait
  fi
fi

