/*

This script has a couple of operational assumptions: 

 - A valid AMI already exists. This should be a Centos 7 t2.micro with latest updates and docker+compose installed.
 - You have a local copy of a valid .pem which exists for your user in AWS IAM. 
 - Set the var for the path to the above file in .tf vars. 
 - Make sure you have the AWS CLI installed, use 'aws configure' to set your credentials

*/


// Provider/region:
provider "aws" {
  region = var.region
}


// Associate an elastic IP with the created AWS instance:
resource "aws_eip_association" "hack-eip_assoc" {
  instance_id   = aws_instance.hack-terraform-test-instance.id
  allocation_id = var.aws_eip_allocation_id
}


// Main EC2 instance setup:
resource "aws_instance" "hack-terraform-test-instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.hack-subnet_public.id
  key_name      = var.public_key_name
  vpc_security_group_ids = [aws_security_group.hack-security_group_instance.id]
  associate_public_ip_address = true


  // Copy all code into the '/app' on the remote instance:
  provisioner "file" {
    source      = "./code"
    destination = "/tmp"

    connection {
      host = self.public_ip
      type = "ssh"
      user = "centos"
      private_key = file(var.pem_file_path)
    }
  }

  // Commands to run after copy, start the docker-compose stack:
  provisioner "remote-exec" {
    inline = [
      "cd /tmp/code",
      "docker-compose up",
    ]

    connection {
      host = self.public_ip
      type = "ssh"
      user = "centos"
      private_key = file(var.pem_file_path)
    }
  }


  tags = {
    Name = "terraform-test-instance"
  }

}


// AWS security group for use with EC2 instance:
resource "aws_security_group" "hack-security_group_instance" {
  name = "terraform-test-instance"
  vpc_id = aws_vpc.hack-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
}


// Subnet
resource "aws_subnet" "hack-subnet_public" {
  vpc_id = aws_vpc.hack-vpc.id
  cidr_block = var.cidr_subnet
  map_public_ip_on_launch = "true"
  depends_on = [aws_internet_gateway.hack-igw]
  availability_zone = var.availability_zone
  tags = {
    "Environment" = var.environment_tag
  }
}


// Route table
resource "aws_route_table" "hack-rtb_public" {
  vpc_id = aws_vpc.hack-vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.hack-igw.id
  }

  tags = {
    "Environment" = var.environment_tag
  }
}


// Route table public
resource "aws_route_table_association" "hack-rta_subnet_public" {
  subnet_id      = aws_subnet.hack-subnet_public.id
  route_table_id = aws_route_table.hack-rtb_public.id
}


// Internet gateway
resource "aws_internet_gateway" "hack-igw" {
  vpc_id = aws_vpc.hack-vpc.id
  tags = {
    "Environment" = var.environment_tag
  }
}


// VPC
resource "aws_vpc" "hack-vpc" {
  cidr_block = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Environment" = var.environment_tag
  }
}