# Install certbot
# sudo add-apt-repository ppa:certbot/certbot
# sudo apt install python-certbot-apache

# Generate certificates
sudo certbot certonly --manual \
    --manual-auth-hook ./certbotAzureDns.sh \
    --manual-cleanup-hook ./certbotAzureClean.sh \
    --preferred-challenges dns --agree-tos \
    -d '*.tomaskubica.in' \
    -d '*.cloud.tomaskubica.in' \
    -d '*.i.cloud.tomaskubica.in' \
    -d '*.nginx.i.cloud.tomaskubica.in' \
    -d '*.istio.cloud.tomaskubica.in'

echo "Key in base64:"
sudo cat /etc/letsencrypt/live/tomaskubica.in-0001/privkey.pem | base64 -w 0; echo  
echo "Cert in base64:" 
sudo cat /etc/letsencrypt/live/tomaskubica.in-0001/cert.pem | base64 -w 0; echo
