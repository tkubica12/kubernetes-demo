FROM ubuntu:18.04

RUN apt update && apt install dnsutils curl jq -y
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

CMD tail -f /dev/null