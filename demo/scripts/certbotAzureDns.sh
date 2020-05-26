#!/bin/bash
zoneName="tomaskubica.in"
rg=shared-services
rs=_acme-challenge.${CERTBOT_DOMAIN%.$zoneName}
echo Adding DNS record $CERTBOT_DOMAIN
az network dns record-set txt add-record -z $zoneName -n $rs -g $rg -v $CERTBOT_VALIDATION
