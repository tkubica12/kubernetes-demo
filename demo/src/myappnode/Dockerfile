FROM node:10

RUN apt update && apt install jq -y

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN chmod +x /app/start.sh

EXPOSE 3000
ENTRYPOINT [ "/app/start.sh" ]