#!/bin/bash
cat <<EOL 
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  
        \/      \/                  \/ 
EOL

sed -i -e "s/#TODOAPIURL#/${TODOAPIURL/'//'/'\/\/'}/" /opt/bitnami/nginx/html/js/app.js 
sed -i -e "s/#INSTANCENAME#/$(cat /etc/hostname)/" /opt/bitnami/nginx/html/js/app.js 
sed -i -e "s/#INSTANCEVERSION#/$(cat /version)/" /opt/bitnami/nginx/html/js/app.js 

echo "$(cat /etc/hostname) - $(cat /version)" > /opt/bitnami/nginx/html/info.txt

/bin/bash /setup.sh
exec /bin/bash /run.sh
