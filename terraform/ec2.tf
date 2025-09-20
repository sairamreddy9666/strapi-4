resource "aws_instance" "strapi" {
  tags = {
    Name = "STRAPI-TASK-4"
    env  = "production"
  }
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = "mumbai-kp"
  availability_zone = "ap-south-1a"
  security_groups   = [aws_security_group.strapi-sg.name]
  root_block_device {
    volume_size = 20
  }
  user_data = file("user_data.sh")
}

