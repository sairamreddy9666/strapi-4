launch instance t2.micro

install docker 

yum install docker -y && systemctl start docker

install terraform

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
    └── terraform
        ├── ec2.tf
        ├── output.tf
        ├── provider.tf
        ├── sg.tf
        ├── user_data.sh
        └── variables.tf

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


cat ec2.tf
resource "aws_instance" "strapi" {
tags = {
Name = "STRAPI-SERVER"
env = "production"
}
ami = var.ami_id
instance_type = var.instance_type
key_name = "mumbai-kp"
availability_zone = "ap-south-1a"
security_groups = [aws_security_group.strapi-sg.name]
root_block_device {
volume_size = 20
}
user_data = templatefile("/root/my-strapi-app/terraform/user_data.tpl", {
    docker_image       = var.docker_image
    dockerhub_user     = var.dockerhub_user
    dockerhub_password = var.dockerhub_password
    db_host           = var.db_host
    db_name           = var.db_name
    db_user           = var.db_user
    db_password       = var.db_password
  })

}


[root@ip-172-31-2-26 terraform]# cat outputs.tf
output "strapi_public_ip" {
  value = aws_instance.strapi.public_ip
}

output "strapi_public_dns" {
  value = aws_instance.strapi.public_dns
}


provider "aws" {
region = var.aws_region
}


[root@ip-172-31-2-26 terraform]# cat sg.tf
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

[root@ip-172-31-2-26 terraform]# cat user_data.tpl
#!/bin/bash

yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker

docker pull $DOCKER_IMAGE

export DATABASE_CLIENT=postgres
export DATABASE_HOST=${db_host}
export DATABASE_PORT=5432
export DATABASE_NAME=${db_name}
export DATABASE_USERNAME=${db_user}
export DATABASE_PASSWORD=${db_password}
export NODE_ENV=production

docker run -d \
  --name strapi \
  -p 1337:1337 \
  -e DATABASE_CLIENT=$DATABASE_CLIENT \
  -e DATABASE_HOST=$DATABASE_HOST \
  -e DATABASE_PORT=$DATABASE_PORT \
  -e DATABASE_NAME=$DATABASE_NAME \
  -e DATABASE_USERNAME=$DATABASE_USERNAME \
  -e DATABASE_PASSWORD=$DATABASE_PASSWORD \
  -e NODE_ENV=$NODE_ENV \
  $DOCKER_IMAGE


[root@ip-172-31-2-26 terraform]# cat variables.tf
variable "aws_region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-01b6d88af12965bb6"
}

variable "docker_image" {
  default = "sairambadari/strapi:latest"
}

variable "dockerhub_user" {
  default = "sairambadari"
}

variable "dockerhub_password" {
  default = "Sairam@9666"
}

variable "db_host" {
  default = "strapi-host"
}

variable "db_name" {
  default = "strapi-db"
}

variable "db_user" {
  default = "strapi-user"
}

variable "db_password" {
  default = "strapi-password"
}
