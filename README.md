launch instance t2.medium for better experience

install docker:

yum install docker -y && systemctl start docker

install terraform:

sudo yum install -y yum-utils

sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

sudo yum -y install terraform

terraform version

npx create-strapi-app my-strapi-app --quickstart  (--quickstart takes sqlite database but its not use for production)

npx create-strapi-app my-strapi-app (add postgres manually)

 Please log in or sign up. Skip
? Do you want to use the default database (sqlite) ? No
? Choose your default database client postgres
? Database name: postgres-db
? Host: postgres
? Port: 5432
? Username: postgres-user
? Password: *****************
? Enable SSL connection: No
? Start with an example structure & data? Yes
? Start with Typescript? Yes
? Install dependencies with npm? Yes
? Initialize a git repository? Yes
? Participate in anonymous A/B testing (to improve Strapi)? No

cd my-strapi-app

tree
.
└── folder
    ├── compose.yml
    ---- Dockerfile
    └── terraform
        ├── ec2.tf
        ├── output.tf
        ├── provider.tf
        ├── sg.tf
        ├── user_data.sh
        └── variables.tf


vim Dockerfile

FROM node:18-alpine as build
WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app

COPY --from=build /app ./
EXPOSE 1337
CMD ["npm", "run", "start"]

using docker file we are generating strapi image and also we need postgers image for database.

so i am creating compose file to check whether both the images are running or not on my local.

vim compose.yml
version: '3'

services:

  postgres:
    image: postgres:15-alpine
    container_name: postgres-container
    restart: always
    environment:
      POSTGRES_USER: strapi
      POSTGRES_PASSWORD: strapi
      POSTGRES_DB: strapi
    networks:
      - strapi-network

  strapi:
    image: sairambadari/strapi:latest
    container_name: strapi-container
    restart: always
    environment:
      DATABASE_CLIENT: postgres
      DATABASE_NAME: strapi
      DATABASE_HOST: postgres   # <-- must match service name
      DATABASE_PORT: 5432
      DATABASE_USERNAME: strapi
      DATABASE_PASSWORD: strapi
    ports:
      - "1337:1337"
    depends_on:
      - postgres
    networks:
      - strapi-network

networks:
  strapi-network:
    name: strapi-network

docker compose up -d

docker ps

this will create containers using compose file

we can access the application using instance ip+1337.

we can also check database whether its storing data or not, through postgres container

docker exec -it 35f1242c293e bash

psql -U strapi -d strapi (login using my database username and password)

SELECT id, firstname, lastname, email, created_at
FROM admin_users;                  (checking its storing in postgres database).

exit

now the main goal is deploying strapi application in production instance using terraform based on this images.

mkdir terraform (creating seperate folder for terraform files)\

cd terraform

vim  ec2.tf
resource "aws_instance" "strapi" {
  tags = {
    Name = "STRAPI-TASK-4"
    env  = "production"
  }
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = "first-kp"
  availability_zone = "ap-south-1a"
  security_groups   = [aws_security_group.strapi-sg.name]
  root_block_device {
    volume_size = 20
  }
  user_data = file("user_data.sh")
}


vim output.tf
output "strapi_public_ip" {
  value = aws_instance.strapi.public_ip
}

output "strapi_public_dns" {
  value = aws_instance.strapi.public_dns
}

vim provider.tf
provider "aws" {
  region = "ap-south-1"
}

vim sg.tf
resource "aws_security_group" "strapi-sg" {
  name        = "strapi-sg"
  description = "allow traffic to strapi"

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

vim user_data.sh
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

vim variables.tf
variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-01b6d88af12965bb6"
}

this will create infra in production server and we can acess through instance public ip + 1337 port no. or else we are generating public dns using output.tf we can also access application.

This is the final project.
