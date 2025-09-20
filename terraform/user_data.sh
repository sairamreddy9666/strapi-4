#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker

docker run -d --name postgres-container \
  -e POSTGRES_USER=strapi \
  -e POSTGRES_PASSWORD=strapi \
  -e POSTGRES_DB=strapi \
  -p 5432:5432 \
  postgres:15-alpine

sleep 10

POSTGRES_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgres-container)

docker run -itd --name strapi-container \
  -e DATABASE_CLIENT=postgres \
  -e DATABASE_NAME=strapi \
  -e DATABASE_HOST=$POSTGRES_IP \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=strapi \
  -e DATABASE_PASSWORD=strapi \
  -p 1337:1337 \
  sairambadari/strapi:latest

