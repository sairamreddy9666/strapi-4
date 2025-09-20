# Strapi + Postgres Deployment on AWS using Terraform and Docker

This project demonstrates deploying a Strapi application with a PostgreSQL database on an AWS EC2 instance using Terraform and Docker. The deployment uses Docker containers for both the Strapi app and Postgres, and automates setup via Terraform and EC2 `user_data`.

---

# 1️⃣ Launch EC2 Instance

Instance type: t2.medium (2 vCPU, 4 GB RAM — good for running Strapi + Postgres).

OS: Amazon Linux 2.

Key pair: select or create a key pair for SSH.

Security Group: allow at least:

SSH: 22 from your IP

HTTP: 80 (if you want web access)

Strapi port: 1337 (optional for testing)

# 2️⃣ Connect to EC2 via SSH

ssh -i <your-key.pem> ec2-user@<EC2_PUBLIC_IP>


# 3️⃣ Install Docker

sudo yum update -y

sudo yum install docker -y

sudo systemctl start docker

sudo systemctl enable docker

docker --version

# 4️⃣ Install Terraform

sudo yum install -y yum-utils

sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

sudo yum install -y terraform

terraform version

# 1️⃣ Create Strapi App

For development/testing (SQLite):

npx create-strapi-app my-strapi-app --quickstart

Quickstart uses SQLite, which is not recommended for production.

# For production with PostgreSQL:

npx create-strapi-app my-strapi-app

? Do you want to use the default database (sqlite) ? No

? Choose your default database client postgres

? Database name: postgres-db

? Host: postgres

? Port: 5432

? Username: postgres-user

? Password: <your-password>

? Enable SSL connection: No

? Start with an example structure & data? Yes

? Start with Typescript? Yes

? Install dependencies with npm? Yes

? Initialize a git repository? Yes

? Participate in anonymous A/B testing (to improve Strapi)? No

Notes:

Replace postgres-db, postgres-user, and password with your Postgres credentials.

Host: postgres is used if you run Postgres in a Docker container and the service name is postgres.

If Postgres is on another server, use its IP or DNS.

# 2️⃣ Navigate to your project

cd my-strapi-app

# 1️⃣ Project Structure
.
└── folder
    ├── compose.yml       # Docker Compose for Strapi + Postgres
    
    ├── Dockerfile        # Builds Strapi Docker image
    
    └── terraform         # Terraform scripts for production EC2
    
        ├── ec2.tf
        
        ├── output.tf
        
        ├── provider.tf
        
        ├── sg.tf
        
        ├── user_data.sh
        
        └── variables.tf
        

# 2️⃣ Dockerfile (Strapi)

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


# ✅ Multi-stage build reduces image size.

# 3️⃣ Build and Push Strapi Docker Image

docker build -t sairam/strapi:latest .

docker login

docker push sairam/strapi:latest


Make sure you use your Docker Hub username (sairam in this case).

If it’s a private repository, you’ll need credentials on the production server to pull the image.

# 1️⃣ docker-compose.yml Overview

Create a compose.yml with Strapi + Postgres so you can test locally:

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
      
      DATABASE_HOST: postgres
      
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

Strapi container depends on Postgres.

Both containers share the same custom network: strapi-network.

Strapi connects to Postgres using the service name postgres as host.

# 2️⃣ Run Containers Locally

docker compose up -d

docker ps

You should see both strapi-container and postgres-container running.

# 3️⃣ Test Database Connectivity

docker exec -it postgres-container bash

psql -U strapi -d strapi

SELECT id, firstname, lastname, email, created_at

FROM admin_users;

exit

This confirms that Strapi is successfully storing data in Postgres.

# 4️⃣ Access the Application

Open your browser and go to:

http://<LOCAL_IP_OR_INSTANCE_IP>:1337

Strapi admin panel should be accessible and functional.

# 5️⃣ Push Postgres Image 

docker push sairambadari/postgres:15-alpine

Normally you can use the official postgres:15-alpine from Docker Hub, but if you have custom changes, push it to your repository.

# 1️⃣ Terraform Folder Structure

terraform/

├── ec2.tf          # EC2 instance resource

├── output.tf       # Outputs public IP and DNS

├── provider.tf     # AWS provider

├── sg.tf           # Security group

├── user_data.sh    # Script to install Docker & run containers

└── variables.tf    # Instance type & AMI variables

# 2️⃣ EC2 Resource (ec2.tf)

resource "aws_instance" "strapi" {

  ami               = var.ami_id
  
  instance_type     = var.instance_type
  
  key_name          = "first-kp"
  
  availability_zone = "ap-south-1a"
  
  security_groups   = [aws_security_group.strapi-sg.name]

  root_block_device {
  
    volume_size = 20
    
  }

  tags = {
  
    Name = "STRAPI-TASK-4"
    
    env  = "production"
    
  }

  user_data = file("user_data.sh")
  
}

Launches EC2 with Docker installed via user_data.sh.

Automatically pulls and runs Postgres and Strapi containers.

# 3️⃣ Security Group (sg.tf)

resource "aws_security_group" "strapi-sg" {

  name        = "strapi-sg"
  
  description = "allow traffic to strapi"

  ingress {
  
    from_port   = 1337
    
    to_port     = 1337
    
    protocol    = "tcp"
    
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  ingress { from_port = 22; to_port = 22; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  
  ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  
  ingress { from_port = 5432; to_port = 5432; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }

  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  
}

Allows SSH, HTTP, Strapi (1337), and Postgres (5432) traffic.

⚠️ Recommendation: Restrict 5432 to your IP in production.

# 4️⃣ User Data Script (user_data.sh)

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

Installs Docker, pulls images, and runs containers.

Dynamically retrieves Postgres container IP to configure Strapi.

# 5️⃣ Terraform Variables (variables.tf)

variable "instance_type" {

  default = "t2.micro"
  
}

variable "ami_id" {

  default = "ami-01b6d88af12965bb6"
  
}

You can override these when running terraform apply if you want t2.medium for better performance.

# 6️⃣ Outputs (output.tf)

output "strapi_public_ip" {

  value = aws_instance.strapi.public_ip
  
}

output "strapi_public_dns" {

  value = aws_instance.strapi.public_dns
  
}

Once Terraform finishes, you can access Strapi via:

http://<strapi_public_ip>:1337

or

http://<strapi_public_dns>:1337

# 7️⃣ Deployment Steps

terraform init

terraform plan

terraform apply --auto-approve

After apply, Terraform outputs the public IP and DNS of your EC2 instance.

# 8️⃣ Access Application

Strapi admin panel: http://<EC2_PUBLIC_IP>:1337/admin

Postgres: connect via docker exec -it postgres-container psql -U strapi -d strapi

# 9️⃣ Best Practices

Use t2.medium or larger for production Strapi.

Use Docker volumes to persist Postgres data.

Do not expose Postgres 5432 publicly in production.

✅ This setup gives you a fully automated Strapi + Postgres production deployment on AWS using Terraform and Docker.
