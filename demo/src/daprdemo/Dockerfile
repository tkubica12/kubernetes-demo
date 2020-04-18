FROM python:3-buster

RUN useradd user -d /home/user -m 

USER user
ENV PATH="/home/user/.local/bin:${PATH}"
RUN pip install --user flask flask_cors azure-servicebus
COPY --chown=user:user *.py /home/user/
COPY --chown=user:user *.sh /home/user/
RUN chmod +x /home/user/*.sh
WORKDIR /home/user

ENTRYPOINT ["tail", "-f", "/dev/null"]