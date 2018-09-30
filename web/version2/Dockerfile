FROM ubuntu

COPY web2 /usr/local/bin/web2

RUN chmod +x /usr/local/bin/web2 && apt-get update && apt-get install uuid-runtime

CMD ["/usr/local/bin/web2"] 