terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# 1. Создаем нашу сеть (VPC)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "My-Final-Project-VPC"
  }
}

# 2. Создаем "улицу" (подсеть) внутри нашей сети
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Автоматически выдавать публичный IP-адрес

  tags = {
    Name = "My-Public-Subnet"
  }
}

# 2.1 Создаем "ворота" в интернет
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "My-Internet-Gateway"
  }
}

# 2.2 Создаем "карту дорог" (таблицу маршрутизации), чтобы трафик ходил в интернет
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "My-Public-Route-Table"
  }
}

# 2.3 Связываем нашу "улицу" с "картой дорог"
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# 3. Создаем "охрану" (файрвол), чтобы разрешить доступ
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Правило для SSH (порт 22) - чтобы мы могли подключаться
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Внимание: для учебы разрешаем SSH отовсюду, на работе здесь был бы ваш IP
  }

  # Правило для HTTP (порт 80) - чтобы пользователи могли видеть сайт
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Правило для исходящего трафика (разрешаем серверу ходить в интернет, например, для скачивания Docker-образов)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "My-Web-SG"
  }
}

# 4. Создаем наш сервер (EC2)
resource "aws_instance" "web" {
  # Правильный AMI для Ubuntu 22.04 в регионе eu-north-1 (Стокгольм)
  ami           = "ami-07e075f00c26b085a"

  # Правильный тип инстанса, который входит в бесплатный тариф
  instance_type = "t3.micro"

  # Имя ключа, который мы создали вручную в консоли AWS
  key_name      = "my-aws-key"
  
  # Указываем, на какой "улице" его строить
  subnet_id = aws_subnet.main.id
  
  # Прикрепляем нашу "охрану"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Зависит от создания "ворот", чтобы сервер создавался только после того, как есть доступ в интернет
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "My-Final-Project-Server"
  }
}

# 5. Просим Terraform показать нам публичный IP-адрес созданного сервера
output "public_ip" {
  description = "Public IP address of our web server"
  value       = aws_instance.web.public_ip
}