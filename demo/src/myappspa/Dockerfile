FROM bitnami/nginx:1.14.2
COPY --chown=1001:1001 src/ /opt/bitnami/nginx/html
COPY --chown=1001:1001 startup.sh version /
USER 1001
ENTRYPOINT [ "/bin/bash", "/startup.sh" ]
