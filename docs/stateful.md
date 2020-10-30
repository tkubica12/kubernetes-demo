# Stateful applications, StatefulSets, Persistent Volume, Backup and DR with Heptio Ark
Deployments in Kubernetes are great for stateless applications, but statful apps, eg. databases. might require different handling. For example we want to use persistent storage and make sure, that when pod fails, new is created mapped to the same persistent volume (so data are persisted). Also in stateful applications we want to keep identifiers like network (IP address, DNS) when pod fails and needs to be rescheduled. Also when multiple replicas are used we need to start them one by one, because aften first instance is going to be master and others slave (so we need to wait for first one to come up first). If we need to scale down, we want to do this from last instance (not to scale down by killing first instance which is likely to be master). More details can be found in documentation.

- [Stateful applications, StatefulSets, Persistent Volume, Backup and DR with Heptio Ark](#stateful-applications-statefulsets-persistent-volume-backup-and-dr-with-heptio-ark)
- [Persistent Volumes for data persistence](#persistent-volumes-for-data-persistence)
  - [Using Azure Disks as Persistent Volume](#using-azure-disks-as-persistent-volume)
  - [Using Azure Files as Persistent Volume](#using-azure-files-as-persistent-volume)
  - [Clean up](#clean-up)
- [Stateful applications with StatefulSets](#stateful-applications-with-statefulsets)
  - [StatefulSets](#statefulsets)
  - [Create StatefulSet with Volume template for Postgresql](#create-statefulset-with-volume-template-for-postgresql)
  - [Periodically backup DB to Azure Blob with CronJob](#periodically-backup-db-to-azure-blob-with-cronjob)
    - [Create storage and container, get credentials](#create-storage-and-container-get-credentials)
    - [Container image for backup job](#container-image-for-backup-job)
    - [Prepare secrets](#prepare-secrets)
    - [Use CronJob to schedule backup job](#use-cronjob-to-schedule-backup-job)
    - [Clean up](#clean-up-1)
- [Heptio Ark - business continuity solution](#heptio-ark---business-continuity-solution)
  - [Gather all details and prepare resources in Azure](#gather-all-details-and-prepare-resources-in-azure)
  - [Deploy Ark](#deploy-ark)
  - [Download Ark client](#download-ark-client)
  - [Create stateful application](#create-stateful-application)
  - [Backups with Volume snapshots](#backups-with-volume-snapshots)
    - [Create backup](#create-backup)
    - [Test accidental delete and restore](#test-accidental-delete-and-restore)
    - [Deploy in different AKS cluster](#deploy-in-different-aks-cluster)
  - [Backup with Restic](#backup-with-restic)

In this demo we will deploy single instance of PostgreSQL.

# Persistent Volumes for data persistence
In order to deploy stateful services we first need to make sure we gain persistency of data storage. Without Persistent Volumes all data is stored on Kubernetes nodes that could fail at any time. Should Pods write data that need to be persistent we need to store them differently. Azure comes with 2 different implementations - Azure Disk or Azure Files and both come with advantages and disadvantages.

Azure Disk
* Full support for standard a premium storage
* Full Linux file system compatibility including permissions etc.
* Cannot be shared with multiple Pods
* Cannot be access directly outside of Kubernetes cluster (unless disk is disconnected and connected to Linux VM in Azure)
* There is limit on number of Disk that can be attached to VM depending on VM size/SKU. When using small VMs you might hit this.
* It might take few minutes to create and attach disk (Pod will be pending), not ideal when you use singleton (eg. single mysql instance) rather than cluster and expect fast recovery

Azure Files (implemented via SMB as a service)
* Can be shared by multiple Pods (eg. for quorum or static web content)
* Can be accessed from outside of Kubernetes cluster via SMB protocol (including apps, VMs in Azure, PaaS services, client notebooks or on-premises resources)
* Due to SMB/CIFS limitations is not compatible with full Linuf FS features (eg. cannot store Linux permissions data)
* High performance available with Premium Files, but that is currently in preview only
* No limitations in number of Volumes that could be attached
* Fast attach

Azure NetApp Files via NFS
* Very good performance
* Shared access supported

# In-tree vs. CSI drivers
AKS currently comes with native support for Azure Disks and Azure Files. In future versions (1.21) community plans to make newer out-of-tree CSI implementations default. In our demo we will use CSI.

## Using Azure Disks as Persistent Volume
First install CSI for Azure Disk.

If using managed identity make sure AKS can create disks in target resource group.
```bash
rg=$(az aks show -n kubedisk -g kubedisk --query nodeResourceGroup -o tsv)
identity=$(az aks show -n kubedisk -g kubedisk --query identityProfile.kubeletidentity.objectId -o tsv)
az role assignment create --role Contributor --assignee-object-id $identity --resource-group $rg
```

Install CSI.

```
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/v0.8.0/deploy/install-driver.sh | bash -s v0.8.0 snapshot --
kubectl apply -f storageClassAzureDiskCSI.yaml
kubectl get storageclasses
```

Let's create Presistent Volume Claim and check how it creates actual Persistent Volume

```
kubectl apply -f persistentVolumeClaimDisk.yaml
kubectl get pvc
kubectl get pv
```

Make sure volume is visible in Azure. You find it in MC... resource group with name similar to kubernetes-dynamic-pvc-823fe291-85c3-11e8-a134-462d743040a1

Azure Disk is created in some Availability Zone in not predictable fashion. When using availability zones it is better not to create disk immediately, but rather wait for first consumer. Sheduler will create Pod and based on its zone disk will be created in right one. This allows together with using node affinity to make sure workload is distributed between zones.

Change storage class to use late binding.

```bash
kubectl delete -f persistentVolumeClaimDisk.yaml
kubectl delete -f storageClassAzureDiskCSI.yaml
kubectl apply -f storageClassAzureDiskCSI-latebinding.yaml
```

We can create Pod, attach it our Volume and write some data.

```
kubectl apply -f podPvcDisk.yaml
kubectl apply -f persistentVolumeClaimDisk.yaml
kubectl exec pod-pvc-disk -- bash -c 'echo My data > /mnt/azure/file.txt'
kubectl exec pod-pvc-disk -- cat /mnt/azure/file.txt
```

## Using Azure Files as Persistent Volume
Let's deploy CSI for Azure Files.

```
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/v0.8.0/deploy/install-driver.sh | bash -s v0.8.0 snapshot --

kubectl apply -f storageClassFilesCSI.yaml
```

We will deploy PVC with managed-files storage class.
```
kubectl apply -f persistentVolumeClaimFiles.yaml
```

We should see new storage account and share available in Azure resource group.


Let's run Pod that uses Files as Persistent Volume. You can port-forward to access page with content being written and updated every second on volume.

```
kubectl apply -f podPvcFiles.yaml
```

Often rather than automatically creating file shares you want to have share managed outside and just point Pods to it. To achieve that we will not use storageClass, but rather directly create PV and PVC.

First create storage account, share and upload some content.

```bash
az storage account create -n mojerucneudelanastorage -g MC_kubefiles_kubefiles_westeurope
az storage share create -n mujshare --account-name mojerucneudelanastorage --account-key \
  $(az storage account keys list -n mojerucneudelanastorage -g MC_kubefiles_kubefiles_westeurope --query [0].value -o tsv)
echo Ahojky! > index.html
az storage file upload -s mujshare --source ./index.html --account-name mojerucneudelanastorage --account-key \
  $(az storage account keys list -n mojerucneudelanastorage -g MC_kubefiles_kubefiles_westeurope --query [0].value -o tsv)
rm index.html
```

Deploy PV, PVC and Pod.

```bash
kubectl apply -f podStaticFilesPV.yaml
```

## Taking snapshots
CSI drivers allow for taking snapshots by calling azure to snapshot disk or files.

Let's start simply with Azure Files and create snapshot.

```bash
kubectl apply -f snapshotClassFiles.yaml
kubectl apply -f snapshotFiles.yaml
```

With Azure Disk implementation we can create snapshot, clone from existing disk or snapshot and resize volume.

Create disk snapshot.

```bash
kubectl apply -f snapshotClassDisk.yaml
kubectl apply -f snapshotDisk.yaml
```

Let's now create new volume from this snapshot and run Pod using it.

```bash
kubectl apply -f diskFromSnapshot.yaml
```

We can also clone disk directly from existing one.


```bash
kubectl apply -f diskClone.yaml
```

## Disk as raw device
Azure Disk is mapped to container as file system and CSI driver supports major systems such as ext4 (default), ext3, ext2 or xfs. Should you need something very specific or even completely raw device, it is supported.


```bash
kubectl apply -f persistentVolumeClaimRaw.yaml
kubectl apply -f podPvcRaw.yaml
```

Connect to container and check device. We can use low level commands to work with it or create our own file system.

```
kubectl exec -ti nginx-raw -- bash

root@nginx-raw:/# ls /dev/x*
/dev/xvda

root@nginx-raw:/# dd if=/dev/zero of=/dev/xvda bs=1024k count=100
100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.0743379 s, 1.4 GB/s
```


## Clean up
```
kubectl delete -f podPvcDisk.yaml
kubectl delete -f podPvcFiles.yaml
kubectl delete -f persistentVolumeClaimDisk.yaml
kubectl delete -f persistentVolumeClaimFiles.yaml
```

# Stateful applications with StatefulSets
Having persistent volumes is important part of managing stateful applications, but there are more things to take care of. Kubernetes Deployment has few limitations when using with statefull apps:
* Deployment creates Pods in parallel. Stateful apps often need to start sequentially - spin up first node, make it initialize and become master and after that spin up second node, connect it to master and make it assume agent/slave/minion role. Also when Pod is in terminating state, Deployment starts creating new one immediately, but that might create two running services accessing the same data - StatefulSet always wait till Pod is terminated.
* Pods with deployments do not have predictable names and those are not persistent. When Pods is rescheduled to different Node it does not keep its configurations such as name.
* Deployments are creating Pod replicas with each attaching the same shared Volume. This is fine for content of web farm, but not for replicated services such as databases.
* During scale-down operation Pods are killed with no order guarantees so it can easily kill Pod that has been created first who became master and cause new master elections that can bring downtime

StatefulSets are designed to behave differently and solve those challanges.

## StatefulSets
First let's explore behavior of StatefulSet on simple example and later add Volumes and real stateful application like database.

### StatefulSet basics

We will run very simple StatefulSet with init container. Observe that Pods are started one by one (only after one Pod goes into full Running state next one is started) and also pod names are predictable (stateful-0, stateful-1 and so on).

```
kubectl apply -f statefulSet.yaml
kubectl get pods -w
```

We will no kill one of Pods and make sure when new one is automatically created it assumes the same predictable name.

```
kubectl delete pod stateful-1
kubectl get pods -w
```

In case of stateful applications nodes sometimes assume specific roles such as master and agent and your client needs to send its writes only to master. If app itself does not have any routing mechanism implemented it is responsibility of client to send traffic to correct Pod (eg. via client library). Therefore we do not want simple balancing with virtual IP but rather create DNS record gives client full list of instances to choose from. To achieve that we have deployed headless Service, which does not provide load balancing, just discovery of individual Pods.

```
kubectl apply -f podUbuntu.yaml
kubectl exec ubuntu -- bash -c 'apt update && apt install dnsutils -y && dig stateful.default.svc.cluster.local'
```

### StatefulSet with zone availability and persistent volume template
We will now create StatefulSet with two replicas. We will use podAntiAffinity to make sure replicas are running in different availability zones. StatefulSet will use volume template so each replica will get its own disk in respective zone.

```
kubectl apply -f statefulSetNginx.yaml
```

Make sure both Pods are running and use port-forward to check NGINX is alive and serving content from Volume and adding entries to it.

Let's now simulate cluster upgrade by draining (safely removing) node on which one of our Pods run.

```bash
kubectl drain aks-nodepool1-30410574-vmss000002 --ignore-daemonsets --delete-local-data 
```

If you have more nodes in the same zone, Pod will be terminated and started elsewhere. If you do not have node in the same zone Pod cannot start as disk is bounded to specific zone only and cannot be automatically transfered.


### StatefulSet with PostgreSQL singleton ?
Now we will deploy something more useful - let's create single instance of PostgreSQL database. This will be pretty easy and when we loose the Pod for instance due to agent failure Kubernetes will reshedule it and point to the same storage. This is not really HA solution, but gives at least basic automated recovery. Deploying actual HA cluster is complex as it requires separate monitoring solution to initiate fail over and proxy client to point to the right node - you can check Stolon project for more details. In HA scenarios I would strongly recommend to go with Azure Database for PostgreSQL (and other managed databases such as SQL, MySQL or CosmosDB with SQL, MongoDB or Cassandra APIs). Nevertheles for simple scenarios or testing we might be fine with just one instance using StatefulSet.

We are going to deploy PostgreSQL instance with StatefulSet. First we will create Secret with DB password and then deploy our yaml template.

```
printf Azure12345678 > dbpassword
kubectl create secret generic dbpass --from-file=./dbpassword
rm dbpassword

kubectl create -f statefulSetPVC.yaml
kubectl get pvc -w
kubectl get statefulset -w
kubectl get pods -w
kubectl logs postgresql-0
```

We will now connect to database and store some data.

```
kubectl exec -ti postgresql-0 -- psql -Upostgres
CREATE TABLE mytable (
    name        varchar(50)
);
INSERT INTO mytable(name) VALUES ('Tomas Kubica');
SELECT * FROM mytable;
\q

Destroy Pod, make sure StatefulSet recovers and data are still there
```
kubectl delete pod postgresql-0
kubectl exec -ti postgresql-0 -- psql -Upostgres -c 'SELECT * FROM mytable;'
```

Note that we can also delete StatefulSet without deleting PVC, go to Azure portal, dettach disk from Kubernetes, attach it to some standard VM and get access to data by mount file system on Azure Disk.

## Periodically backup DB to Azure Blob with CronJob
With containers we should subscribe to single task per container strategy. Therefore scheduled backup process for our DB should be implemented as separate container. We will use CronJob to schedule regular backups and use environmental variables and secrets to pass information to container. That will contain simple Python script to backup our database and upload to Azure Blob Storage.

### Create storage and container, get credentials
```
az group create -n backups -l westeurope
az storage account create -n tomasbackupdbstore -g backups -l westeurope --sku Standard_LRS
export storagekey=$(az storage account keys list -g backups -n tomasbackupdbstore --query [0].value -o tsv)
az storage container create -n backup --account-name tomasbackupdbstore --account-key $storagekey
```

### Container image for backup job
You can use container image right from Docker Hub, but if you are intersted on how that works please look into backupJob folder. backup.py is simple script that reads inputs from environmental variables (we will pass this to container via Pod definition) and secrets from specific files (we will mount Kubernetes secrets). You can build container with Dockerfile that installs required dependencies such as Python Azure Storage library and pg_dump PostgreSQL backup utility and copies script to image. Here is how you do it:
```
cd ./backupJob
docker.exe build -t tkubica/backupjob .
docker.exe push tkubica/backupjob
```

### Prepare secrets
We will pass non-sensitive information to our container via environmental variables. Nevertheless two items are considered sensitive - storage key and DB password. Therefore we will rather use concept of Kubernetes secret to pass this to container in more secured way. We need to create files with secrets and then create secret. This object is than mapped to Pod as volume.

```
echo -n 'Azure12345678' > dbPassword.txt
echo -n $storagekey > storageKey.txt
kubectl create secret generic backupcredentials --from-file=./dbPassword.txt --from-file=./storageKey.txt
rm dbPassword.txt
rm storageKey.txt
```

### Use CronJob to schedule backup job
Read throw cronJobBackup.yaml. We are (for demonstration purposes) scheduling backup to run every minute and provide Pod template. In that we use env to pass information about DB host, username etc. and also mount volume with secrets.

```
kubectl create -f cronJobBackup.yaml
kubectl get pods -w
az storage blob list --account-name tomasbackupdbstore --account-key $storagekey -c backup
```

### Clean up
```
kubectl delete -f cronJobBackup.yaml
kubectl delete -f statefulSetPVC.yaml
kubectl delete secret dbpass
kubectl delete secret backupcredentials
az group delete -n backups -y --no-wait
kubectl delete pvc postgresql-volume-claim-postgresql-0
```

# Heptio Ark - business continuity solution
## Gather all details and prepare resources in Azure
We need to create Resource Group and storage account for backups including container. Next we will gather all login and configuration details and store it as Kubernetes Secret.

```
AZURE_BACKUP_RESOURCE_GROUP=aks-backups
az group create -n $AZURE_BACKUP_RESOURCE_GROUP --location westeurope

AZURE_STORAGE_ACCOUNT_ID="aksbackupsva4ai"
az storage account create \
    --name $AZURE_STORAGE_ACCOUNT_ID \
    --resource-group $AZURE_BACKUP_RESOURCE_GROUP \
    --sku Standard_GRS \
    --encryption-services blob \
    --https-only true \
    --kind BlobStorage \
    --access-tier Hot
az storage container create -n ark --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID
```

Deploy CRDs, namespace and rbac

```
cd ark
kubectl apply -f 00-prereqs.yaml
```

```
AZURE_RESOURCE_GROUP=MC_aks_aks_westeurope
kubectl create secret generic cloud-credentials \
    --namespace heptio-ark \
    --from-literal AZURE_SUBSCRIPTION_ID=$subscription \
    --from-literal AZURE_TENANT_ID=$tenant \
    --from-literal AZURE_CLIENT_ID=$principal \
    --from-literal AZURE_CLIENT_SECRET=$client_secret \
    --from-literal AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
```

## Deploy Ark
Deploy Ark components

```
kubectl apply -f 00-ark-deployment.yaml
```

Make sure to modify 05-ark-backupstoragelocation.yaml to fit your container name, storage account and resource group, where storage account is deployed. Apply it and also deploy snapshot location.

```
kubectl apply -f 05-ark-backupstoragelocation.yaml
kubectl apply -f 06-ark-volumesnapshotlocation.yaml
```

## Download Ark client

```
wget https://github.com/heptio/ark/releases/download/v0.10.0/ark-v0.10.0-linux-amd64.tar.gz
sudo tar xvf  ./ark-v0.10.0-linux-amd64.tar.gz -C /usr/local/bin ark 
rm ark-v0.10.0-linux-amd64.tar.gz
```

## Create stateful application
We will use Wordpress Helm chart (please see [Helm](./helm.md) chapter) in specific namespace.

```
kubectl create namespace wp
helm install --namespace wp \
    --name myblog stable/wordpress \
    --set persistence.storageclass=default \
    --set wordpressPassword=Azure12345678
```

When deployment is finished you can go ahead and write a blog post.

## Backups with Volume snapshots
Ark will backup objects descriptions to Blob storage and can use native Azure Disk Snapshot technology to provide extremly fast solution (based on copy on write). Disadvantage is that snapshots can live only in the same region as original disk. This solution is therefore very good for backups to protect from accidental delete, data corruption or need to migrate to different cluster and is very fast so can be done often for low RPO/RTO. Nevertheless should complete region fail snapshot might became unavailable and restore in different region not possible, so this solution is not ideal for cross-region Disaster Recovery purposes.

### Create backup
Ark can schedule backup to run automatically. In our example we will trigger manual backup now.

```
ark backup create --include-namespaces wp --snapshot-volumes -w mybackup
```

### Test accidental delete and restore
In this scenario we will simulate accidental delete of our resources, data coruption due to application bug or any other condition. Delete complete wp namespace.

```
kubectl delete namespace wp
```

Restore from backup

```
ark restore create myrestore --from-backup mybackup -w
```

### Deploy in different AKS cluster
In this scenario we will use backup from one AKS cluster to deploy in different AKS cluster. Such procedure might be useful during migrations to different cluster (different VM sizing, configuration, networking) or to create clone of production application in testing cluster.

Create different AKS cluster and follow the same deployment procedure (do not forget to reflect to new AZURE_RESOURCE_GROUP) as with first one except for 00-ark-deployment.yaml which you will replace by 00-ark-deployment-read-only.yaml. This is safer choice as any potential configuration error on new cluster cannot corrupt your backup.

```
ark backup get
ark restore create mytransfer --from-backup mybackup -w
```

## Backup with Restic
Alternative to snapshot technology integrated with Azure Disk Snapshot is backup on file system level via Restic. This exports content of Volume using universal format and store it in Azure Blob. As opposed to snapshot technology this allows to backup Azure Files which have no Ark specific implementation. Potentialy it my allow recovery to different region or different storage type (cloud), but that does not work at time of writing this.

First we deploy restic DaemonSet.
```
kubectl apply -f 20-restic-daemonset.yaml
```

Ark will by default use snapshot technology. There are annotations that need to be added to Pods to instruct it to use restic. We should modify Helm chart accordingly, but for now let's just add annotations to running Pods (just for demo purposes).

```
kubectl annotate pods -n wp -l app=mariadb backup.ark.heptio.com/backup-volumes=data
kubectl annotate pods -n wp -l app=myblog-wordpress backup.ark.heptio.com/backup-volumes=wordpress-data
```

Now initiate new backup
```
ark backup create --include-namespaces wp --snapshot-volumes -w resticbackup
```

Follow our previous examples to restore from backup. Note that Ark adds init containers to our Pods for them to wait till Restic restore finish.

```
ark backup get
ark restore create newrestore --from-backup resticbackup -w
```

I have created different AKS cluster in different region and used procedure described previously to install Ark in read only mode. Now it is time to do recovery.
