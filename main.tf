terraform {

  ###### PRORIEDADES PARA REALIZAR DEPLOY VIA ESTEIRA USANDO HCP

  backend "remote" {
    organization = "emock"
    workspaces {
      name = "terraform-github-actions"
    }
  }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "vpc-token-validator" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc-token-validator"
  }
}

resource "aws_subnet" "public-subnet-token-validator" {
  vpc_id            = aws_vpc.vpc-token-validator.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet-token-validator"
  }
}

resource "aws_subnet" "private-subnet-token-validator" {
  vpc_id            = aws_vpc.vpc-token-validator.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"


  tags = {
    Name = "private-subnet-token-validator"
  }
}

resource "aws_internet_gateway" "igw-token-validator" {
  vpc_id = aws_vpc.vpc-token-validator.id

  tags = {
    Name = "igw-token-validator"
  }
}

resource "aws_eip" "nat-eip-token-validator" {
  tags = {
    Name = "nat-eip-token-validator"
  }
}

resource "aws_nat_gateway" "nat-gw-token-validator" {
  allocation_id = aws_eip.nat-eip-token-validator.id
  subnet_id     = aws_subnet.public-subnet-token-validator.id

  tags = {
    Name = "nat-gw-token-validator"
  }
}

resource "aws_route_table" "public-rt-token-validator" {
  vpc_id = aws_vpc.vpc-token-validator.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-token-validator.id
  }
  tags = {
    Name = "public-rt-token-validator"
  }
}

resource "aws_route_table_association" "public-ta-token-validator" {
  subnet_id      = aws_subnet.public-subnet-token-validator.id
  route_table_id = aws_route_table.public-rt-token-validator.id
}

resource "aws_route_table" "private-rt-token-validator" {
  vpc_id = aws_vpc.vpc-token-validator.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-token-validator.id
  }
  tags = {
    Name = "private-rt-token-validator"
  }
}

resource "aws_route_table_association" "private-ta-token-validator" {
  subnet_id      = aws_subnet.private-subnet-token-validator.id
  route_table_id = aws_route_table.private-rt-token-validator.id
}


resource "aws_security_group" "security-group-token-validator" {
  description = "Security group token validator"
  vpc_id      = aws_vpc.vpc-token-validator.id


  ingress = [
    {
      #SSH
      description = "Regra conexao SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      # Ajusta para bloco de IP do GitHub Actions - Avaliar se é possível fazer a integração sem passar pela internet
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },

    {
      # HTTP
      description = "Regra para requisicoes http"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      # Ajusta para bloco de IP do GitHub Actions - Avaliar se é possível fazer a integração sem passar pela internet
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
  ]

  egress = [
    {
      description      = "Regra de saida."
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false

    }
  ]

  tags = {
    Name = "security-group-token-validator"
  }
}

resource "aws_key_pair" "key-pair-token-validator" {
  key_name   = "deployer-key"
  # public_key = file("/Users/developer/.ssh/token-validator-key.pub")
    public_key = var.ssh_public_key

  tags = {
    Name = "key-pair-token-validator"
  }
}

resource "aws_instance" "api-token-validator" {
  ami = "ami-020cba7c55df1f615"
  # instance_type = "t3.small" # 2Vcpu 2GB
  instance_type               = "t2.micro" # 1Vcpu 1GB
  subnet_id                   = aws_subnet.public-subnet-token-validator.id
  vpc_security_group_ids      = [aws_security_group.security-group-token-validator.id]
  key_name                    = aws_key_pair.key-pair-token-validator.key_name
  associate_public_ip_address = true

  # provisioner "local-exec" {
  #   command = "curl -fsSl https://get.docker.com | sh"
  #   # Cria um arquivo na máquina local
  # }
  user_data = <<-EOF
              #!/bin/bash
              curl -fsSl https://get.docker.com | sh
              sudo usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "api-token-validator"
  }
}


# resource "aws_instance" "recurso-subnet-privada" {
#   ami           = "ami-020cba7c55df1f615"
#   # instance_type = "t3.small" # 2Vcpu 2GB
#   instance_type = "t2.micro" # 1Vcpu 1GB
#   subnet_id = aws_subnet.private-subnet-token-validator.id
#   vpc_security_group_ids = [ aws_security_group.security-group-token-validator.id ]
#   key_name = aws_key_pair.key-pair-token-validator.key_name

#   tags = {
#     Name = "recurso-subnet-privada"
#   }
# }