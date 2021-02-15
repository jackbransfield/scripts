/*

This script has a couple of operational assumptions: 

 - A valid AMI already exists. This should be a Centos 7 t2.micro with latest updates and docker+compose installed.
 - You have a local copy of a valid .pem which exists for your user in AWS IAM. 
 - Set the var for the path to the above file in .tf vars. 
 - Make sure you have the AWS CLI installed, use 'aws configure' to set your credentials

*/


// Pem path
variable "pem_file_path" {
  type = string
  default = "/Users/jbransfield/.ssh/admin-testing.pem"
}


// Key pair 
// resource "aws_key_pair" "ec2key" {
//   key_name = "publicKey"
//   public_key = file(var.public_key_path)
// }


// Provider/region:
provider "aws" {
  region = var.region
}


// Main EC2 instance setup:
resource "aws_instance" "mywallst-test-instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.subnet_public.id
  key_name      = var.public_key_name
  vpc_security_group_ids = [aws_security_group.security_group_instance.id]
  associate_public_ip_address = true

  // // Create the directory to which the files will be uploaded to:
  // provisioner "remote-exec" {
  //   inline = [
  //     "sudo yum -y install python-pip",
  //     "pip --version"
  //   ]

  //   connection {
  //     host = self.public_ip
  //     type = "ssh"
  //     user = "centos"
  //     private_key = file(var.pem_file_path)
  //   }
  // }

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
    Name = "mywallst-test-instance"
  }

}


// AWS security group for use with EC2 instance:
resource "aws_security_group" "security_group_instance" {
  name = "mywallst-test-instance"
  vpc_id = aws_vpc.vpc.id

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
resource "aws_subnet" "subnet_public" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.cidr_subnet
  map_public_ip_on_launch = "true"
  availability_zone = var.availability_zone
  tags = {
    "Environment" = var.environment_tag
  }
}


// Route table
resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Environment" = var.environment_tag
  }
}


// Route table public
resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rtb_public.id
}


// Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Environment" = var.environment_tag
  }
}


// VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Environment" = var.environment_tag
  }
}