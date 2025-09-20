output "strapi_public_ip" {
  value = aws_instance.strapi.public_ip
}

output "strapi_public_dns" {
  value = aws_instance.strapi.public_dns
}

