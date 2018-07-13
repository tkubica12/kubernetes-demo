# Stateful applications and StatefulSet with Persistent Volume
Deployments in Kubernetes are great for stateless applications, but statful apps, eg. databases. might require different handling. For example we want to use persistent storage and make sure, that when pod fails, new is created mapped to the same persistent volume (so data are persisted). Also in stateful applications we want to keep identifiers like network (IP address, DNS) when pod fails and needs to be rescheduled. Also when multiple replicas are used we need to start them one by one, because aften first instance is going to be master and others slave (so we need to wait for first one to come up first). If we need to scale down, we want to do this from last instance (not to scale down by killing first instance which is likely to be master). More details can be found in documentation.

- [Stateful applications and StatefulSet with Persistent Volume](#stateful-applications-and-statefulset-with-persistent-volume)
- [Persistent Volumes for data persistence](#persistent-volumes-for-data-persistence)
    - [Using Azure Disks as Persistent Volume](#using-azure-disks-as-persistent-volume)
    - [Using Azure Disks as Persistent Volume](#using-azure-disks-as-persistent-volume)
    - [Clean up](#clean-up)
- [Stateful applications with StatefulSets](#stateful-applications-with-statefulsets)
    - [StatefulSets](#statefulsets)
    - [Create StatefulSet with Volume template for Postgresql](#create-statefulset-with-volume-template-for-postgresql)
    - [Periodically backup DB to Azure Blob with CronJob](#periodically-backup-db-to-azure-blob-with-cronjob)
        - [Create storage and container, get credentials](#create-storage-and-container-get-credentials)
        - [Container image for backup job](#container-image-for-backup-job)
        - [Prepare secrets](#prepare-secrets)
        - [Use CronJob to schedule backup job](#use-cronjob-to-schedule-backup-job)
        - [Clean up](#clean-up)

In this demo we will deploy single instance of PostgreSQL.

# Persistent Volumes for data persistence
In order to deploy stateful services we first need to make sure we gain persistency of data storage. Without Persistent Volumes all data is stored on Kubernetes nodes that could fail at any time. Should Pods write data that need to be persistent we need to store them differently. Azure comes with 2 different implementations - Azure Disk or Azure Files and both come with advantages and disadvantages.

Azure Disk
* Can get very high performance when Premium storage is used (SSD-based)
* Full Linux file system compatibility including permissions etc.
* Cannot be shared with multiple Pods
* Cannot be access directly outside of Kubernetes cluster (unless disk is disconnected and connected to Linux VM in Azure)
* There is limit on number of Disk that can be attached to VM depending on VM size/SKU. When using small VMs you might hit this.
* It might take few minutes to create and attach disk (Pod will be pending)

Azure Files (implemented via SMB as a service)
* Can be shared by multiple Pods (eg. for quorum or static web content)
* Can be accessed from outside of Kubernetes cluster via SMB protocol (including apps, VMs in Azure, PaaS services, client notebooks or on-premises resources)
* Due to SMB/CIFS limitations is not compatible with full Linuf FS features (eg. cannot store Linux permissions data)
* Cannot achieve as low latency and IOPS as Premium storage SSD drives
* No limitations in number of Volumes that could be attached
* Fast attach

## Using Azure Disks as Persistent Volume
Our AKS cluster has Azure Disk persistence volume drivers available by default. We can see two storage classes - default (Standard HDD) and managed-premium (Premium SSD).

```
kubectl get storageclasses
```

Let's create Presistent Volume Claim and check how it creates actual Persistent Volume

```
kubectl get pvc
kubectl get pv
```

Make sure volume is visible in Azure. You find it in MC... resource group with name similar to kubernetes-dynamic-pvc-823fe291-85c3-11e8-a134-462d743040a1

We can create Pod, attach it our Volume and write some data.

```
kubectl apply -f podPvcDisk.yaml
kubectl exec pod-pvc-disk -- bash -c 'echo My data > /mnt/azure/file.txt'
kubectl exec pod-pvc-disk -- cat /mnt/azure/file.txt
```

## Using Azure Disks as Persistent Volume

First we need to create storage account in Azure. Make sure service principal used when creating AKS cluster has access to it (RBAC). If you have let this generated automatically then it is scoped to MC... resource group so we will deploy our storage account there (or add service principal to any storage account in your subscription).

```
az storage account create -n tomaskubefiles \
    -g MC_aksgroup_akscluster_westeurope \
    --sku Standard_LRS 
```

Azure Files storage class is not deployed by default in AKS, so let's do it now. Make sure you modify this yaml to reflect your storage account name. Also since our cluster is RBAC enabled we need to create role binding for persistent-volume-binding.

```
kubectl apply -f storageClassFiles.yaml
```

We will deploy PVC with managed-files storage class.
```
kubectl apply -f persistentVolumeClaimFiles.yaml
```

We should see new share available in our storage account
```
export AZURE_STORAGE_KEY=$(az storage account keys list \
    -g MC_aksgroup_akscluster_westeurope \
    -n tomaskubefiles \
    --query [0].value \
    -o tsv )

az storage share list --account-name tomaskubefiles
```

We should see share with name similar to this: kubernetes-dynamic-pvc-1d504a0b-85c8-11e8-a134-462d743040a1

Let's run two Pod that uses Files as shared Persistent Volume. We can test writing in one and reading in seconds Pod.
```
kubectl apply -f podPvcFiles.yaml
kubectl exec pvc-files1 -- bash -c 'echo My data > /mnt/azure/file.txt'
kubectl exec pvc-files2 -- cat /mnt/azure/file.txt
```

Nevertheless let's show how permissions are not stored with Azure Files implementation.
```
kubectl exec pvc-files1 -- chmod 500 /mnt/azure/file.txt
kubectl exec pvc-files1 -- ls -l /mnt/azure
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
* Deployment creates ports in parallel. Stateful apps sometimess need to start sequentially - spin up first node, make it initialize and become master and after that spin up second node, connect it to master and make it assume agent/slave/minion role
* Pods with deployments do not have predictable names and those are not persistent. When Pods is rescheduled to different Node it does not keep its configurations such as name
* When Pod is using Persistent Volume and fails new pod gets created with new Volume rather than take over of existing one
* During scale-down operation Pods are killed with no order guarantees so it can easily kill Pod that has been created first who became master and cause new master elections that can bring downtime

StatefulSets are designed to behave differently and solve those challanges.

## StatefulSets
First let's explore behavior of StatefulSet on simple example and later add Volumes and real stateful application like database.

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

## Create StatefulSet with Volume template for Postgresql
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
```

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

