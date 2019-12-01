FROM golang:stretch AS build
RUN apt-get update && apt-get install git -y && go get github.com/go-martini/martini
RUN mkdir /build 
ADD . /build/
WORKDIR /build 
RUN go build -o app .

FROM ubuntu:latest AS final
RUN apt-get update && apt-get install iputils-ping curl -y
COPY --from=build /build/app /app/
WORKDIR /app
CMD ["./app"]