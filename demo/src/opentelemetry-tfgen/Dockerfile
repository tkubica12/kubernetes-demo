FROM python:3

ENV APPINSIGHTS_INSTRUMENTATION_KEY=yourinstrumentationkey
ENV APP_NAME=app1
ENV REMOTE_ENDPOINT=http://127.0.0.1:8080/data

WORKDIR /app
COPY . ./
RUN pip3 install -r requirements.txt

EXPOSE 8080
CMD [ "python", "./app.py" ]