FROM ubuntu:17.04

RUN /bin/bash -c 'apt-get update && apt-get install python-pip wget -y; \
    echo deb http://apt.postgresql.org/pub/repos/apt/ zesty-pgdg main > /etc/apt/sources.list.d/pgdg.list; \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -; \
    apt-get update && apt-get install postgresql-client-10 -y; \
    pip install azure-storage-blob'

COPY backup.py \backup.py

ENTRYPOINT python \backup.py