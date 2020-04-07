FROM node:10

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN chmod +x /app/start.sh

EXPOSE 3000
ENTRYPOINT [ "/app/start.sh" ]