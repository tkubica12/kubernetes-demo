FROM ubuntu

COPY web /usr/local/bin/web

RUN chmod +x /usr/local/bin/web && apt-get update && apt-get install uuid-runtime

CMD ["/usr/local/bin/web"] 