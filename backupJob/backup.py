#!/usr/bin/python

from azure.storage.blob import BlockBlobService
from azure.storage.blob import ContentSettings
import datetime
import os

# Get configurations
storageAccount = os.environ['STORAGE_ACCOUNT']
objectName = 'db_{:%Y%m%d%H%M%S}'.format(datetime.datetime.now())
containerName = os.environ['CONTAINER_NAME']
dbUser = os.environ['DB_USER']
dbName = os.environ['DB_NAME']
dbPort = os.environ['DB_PORT']
dbHost = os.environ['DB_HOST']

# Get secrets
dbPasswordFile = open('/backupCredentials/dbPassword.txt', 'r') 
dbPassword = dbPasswordFile.read()

storageKeyFile = open('/backupCredentials/storageKey.txt', 'r') 
storageKey = storageKeyFile.read()

# Backup DB
print 'Backing up'
dumpCommand = 'PGPASSWORD="%s" nice -n 19 pg_dump -C -F c -h%s -U%s -p%s %s > %s' % (dbPassword, dbHost, dbUser, dbPort, dbName, objectName)
os.popen(dumpCommand)

# Upload to Azure Blob
print 'Uploading'
azureStorage = BlockBlobService(account_name=storageAccount, account_key=storageKey)
azureStorage.create_blob_from_path(
    containerName,
    objectName,
    objectName,
    content_settings=ContentSettings(content_type='application/octet-stream')
            )

