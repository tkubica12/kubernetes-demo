# Install Linkerd CLI
wget https://github.com/linkerd/linkerd2/releases/download/stable-2.6.0/linkerd2-cli-stable-2.6.0-linux
sudo mv linkerd2-cli-stable-2.6.0-linux /usr/bin/

linkerd check --pre
linkerd install | kubectl apply -f -
linkerd check

linkerd dashboard 
