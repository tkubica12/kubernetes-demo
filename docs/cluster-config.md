# Merging cluster configurations and using kubectx to switch between clusters

In order to easily switch between clusters let's download kubectx script.

```
sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /usr/local/bin/kubectx
sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/utils.bash -O /usr/local/bin/utils.bash
sudo chmod +x /usr/local/bin/kubectx
```

Set env variable to merge all our configuration files

```
echo 'export KUBECONFIG=~/.kube/config:~/.kube/config-acs:~/.kube/config-azurenet:~/.kube/config-calico'  > .kubeconfig
source .kubeconfig
```

You can now run kubectx to list clusters and switch between them.

```
kubectx
kubectx mojeacsdemo
```