# Stateful applications and StatefulSet with Persistent Volume
Deployments in Kubernetes are great for stateless applications, but statful apps, eg. databases. might require different handling. For example we want to use persistent storage and make sure, that when pod fails, new is created mapped to the same persistent volume (so data are persisted). Also in stateful applications we want to keep identifiers like network (IP address, DNS) when pod fails and needs to be rescheduled. Also when multiple replicas are used we need to start them one by one, because aften first instance is going to be master and others slave (so we need to wait for first one to come up first). If we need to scale down, we want to do this from last instance (not to scale down by killing first instance which is likely to be master). More details can be found in documentation.

- [Stateful applications and StatefulSet with Persistent Volume](#stateful-applications-and-statefulset-with-persistent-volume)
    - [Switch to our AKS or mixed ACS cluster](#switch-to-our-aks-or-mixed-acs-cluster)
    - [Check storage class and create Persistent Volume](#check-storage-class-and-create-persistent-volume)
    - [Create StatefulSet with Volume template for Postgresql](#create-statefulset-with-volume-template-for-postgresql)
    - [Connect to PostgreSQL](#connect-to-postgresql)
    - [Destroy Pod and make sure StatefulSet recovers and data are still there](#destroy-pod-and-make-sure-statefulset-recovers-and-data-are-still-there)
    - [Periodically backup DB to Azure Blob with CronJob](#periodically-backup-db-to-azure-blob-with-cronjob)
        - [Create storage and container, get credentials](#create-storage-and-container-get-credentials)
        - [Container image for backup job](#container-image-for-backup-job)
        - [Prepare secrets](#prepare-secrets)
        - [Use CronJob to schedule backup job](#use-cronjob-to-schedule-backup-job)
        - [Clean up](#clean-up)
    - [Continue in Azure](#continue-in-azure)
    - [Clean up](#clean-up)

In this demo we will deploy single instance of PostgreSQL.

This demo works in both AKS and ACS engine environments.

## Switch to our AKS or mixed ACS cluster
```
kubectx aks
```

or mixed ACS engine

```
kubectx mojeacsdemo
```

## Check storage class and create Persistent Volume
Our ACS cluster has Azure Disk persistence volume drivers setup.

```
kubectl get storageclasses
kubectl create -f persistentVolumeClaim.yaml
kubectl get pvc
kubectl get pv
```

Make sure volume is visible in Azure. 

Clean up.
```
kubectl delete -f persistentVolumeClaim.yaml
```

## Create StatefulSet with Volume template for Postgresql
```
kubectl create -f statefulSetPVC.yaml
kubectl get pvc -w
kubectl get statefulset -w
kubectl get pods -w
kubectl logs postgresql-0
```

## Connect to PostgreSQL
```
kubectl exec -ti postgresql-0 -- psql -Upostgres
CREATE TABLE mytable (
    name        varchar(50)
);
INSERT INTO mytable(name) VALUES ('Tomas Kubica');
SELECT * FROM mytable;
\q
```

## Destroy Pod and make sure StatefulSet recovers and data are still there
```
kubectl delete pod postgresql-0
kubectl exec -ti postgresql-0 -- psql -Upostgres -c 'SELECT * FROM mytable;'
```

## Periodically backup DB to Azure Blob with CronJob
With containers we should apply to single task per container strategy. Therefore scheduled backup process for our DB should be implemented as separate container. We will use CronJob to schedule regular backups and use environmental variables and secrets to pass information to container. That will contain simple Python script to backup our database and upload to Azure Blob Storage.

### Create storage and container, get credentials
```
az storage account create -n tomasbackupdbstore -g mykubeacs -l westeurope --sku Standard_LRS
export storagekey=$(az storage account keys list -g mykubeacs -n tomasbackupdbstore --query [0].value -o tsv)
az storage container create -n backup --account-name tomasbackupdbstore --account-key $storagekey
```

### Container image for backup job
You can use container image right from Docker Hub, but if you are intersted on how that works please look into backupJob folder. backup.py is simple script that reads inputs from environmental variables (we will pass this to container via Pod definition) and secrets from specific files (we will mount Kubernetes secrets). You can build container with Dockerfile that installs required dependencies such as Python Azure Storage library and pg_dump PostgreSQL backup utility and copies script to image. Here is how you do it:
```
cd ./backupJob
docker.exe build -t tkubica/backupdb .
docker.exe push tkubica/backupdb
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
kubectl delete secret backupcredentials
az storage account delete -n tomasbackupdbstore -g mykubeacs -y
```

## Continue in Azure
Destroy statefulset and pvc, keep pv
```
kubectl delete -f statefulSetPVC.yaml
```

Go to GUI and map IaaS Volume to VM, then mount it and show content.
```
ssh tomas@mykubeextvm.westeurope.cloudapp.azure.com
ls /dev/sd*
sudo mkdir /data
sudo mount /dev/sdc /data
sudo ls -lh /data/pgdata/
sudo umount /dev/sdc
```

Detach in GUI

## Clean up
```
kubectl delete pvc postgresql-volume-claim-postgresql-0

```