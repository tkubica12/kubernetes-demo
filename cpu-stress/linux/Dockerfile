FROM ubuntu

COPY runstress.sh /usr/local/bin/runstress.sh

RUN chmod +x /usr/local/bin/runstress.sh && apt-get update && apt-get install stress -y

CMD ["/usr/local/bin/runstress.sh"]