provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA3FQHOVS2TTHFUA74"
  secret_key = var.secret_key
}

variable "secret_key" {
  description = "secret key for the connection"
}


# VPC

resource "aws_vpc" "knowme-vpc" {
  cidr_block = "172.31.0.0/16"
  tags = {
    Name = "KnowMe"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.knowme-vpc.id


}

# Route Table Publica

resource "aws_route_table" "route-table-public" {
  vpc_id = aws_vpc.knowme-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Tabla publica"
  }
}

# Route Table Privada

resource "aws_route_table" "route-table-privada" {
  vpc_id = aws_vpc.knowme-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw-1.id
  }

  tags = {
    Name = "Tabla privada"
  }

  depends_on = [
    aws_nat_gateway.nat-gw-1
  ]
}

# Subnet Publica 1

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.knowme-vpc.id
  cidr_block        = "172.31.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "SubnetPublica1"
  }
}

# Subnet Publica 2

resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.knowme-vpc.id
  cidr_block        = "172.31.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "SubnetPublica2"
  }
}

# Subnet Privada 1

resource "aws_subnet" "subnet-priv-1" {
  vpc_id            = aws_vpc.knowme-vpc.id
  cidr_block        = "172.31.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "SubnetPrivada1"
  }
}

# Subnet Privada 2

resource "aws_subnet" "subnet-priv-2" {
  vpc_id            = aws_vpc.knowme-vpc.id
  cidr_block        = "172.31.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "SubnetPrivada2"
  }
}

# Associate subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route-table-public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.route-table-public.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet-priv-1.id
  route_table_id = aws_route_table.route-table-privada.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.subnet-priv-2.id
  route_table_id = aws_route_table.route-table-privada.id
}

# Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.knowme-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Mongo"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Host-usuarios"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Host-emprendimiento"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Cluster Subnet Group

resource "aws_docdb_subnet_group" "knowme-subnetgroup" {
  name       = "knowme-subnetgroup"
  subnet_ids = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]

  tags = {
    Name = "knowme-subnetgroup"
  }
}

# Cluster DocumentDB

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier     = "knowme-2021-07-12-11-34"
  engine                 = "docdb"
  master_username        = "master"
  master_password        = "trusTU_r+wexag8-uva*"
  db_subnet_group_name   = "knowme-subnetgroup"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  skip_final_snapshot     = true
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 1
  identifier         = "docdb-cluster-demo-0"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = "db.t3.medium"
}

output "mongodb_endpoint" {
  value = aws_docdb_cluster.docdb.endpoint
}

# Create a network interface with an ip in the subnet for server

resource "aws_network_interface" "maintenance-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["172.31.3.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# Assign an elastic IP to the network interface for server

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.maintenance-nic.id
  associate_with_private_ip = "172.31.3.50"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# Assign an elastic IP to the network interface for NAT

resource "aws_eip" "eip-nat" {
  vpc                       = true
}

output "nat_public_ip" {
  value = aws_eip.eip-nat.public_ip
}


# NAT Gateway

resource "aws_nat_gateway" "nat-gw-1" {
  allocation_id = aws_eip.eip-nat.id
  subnet_id     = aws_subnet.subnet-2.id

  tags = {
    Name = "Nat1"
  }
  depends_on = [aws_internet_gateway.gw]
}

# Ubuntu server
resource "aws_instance" "ec2-maintenance" {
  ami                         = "ami-0dc2d3e4c0f9ebd18"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1a"
  key_name                    = "Know-Me-keypair"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.maintenance-nic.id
  }


  tags = {
    Name = "ec2-maintenance"
  }
}

# ECS cluster
resource "aws_ecs_cluster" "know-me-ecs" {
  name = "KnowMe"
}

# Role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "CustomECSTaskExecutionRole"
}

# Task Definition Usuarios
resource "aws_ecs_task_definition" "service-usuarios" {
  family = "Usuarios"
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu       = 256
  memory    = 512
  container_definitions = jsonencode([
    {
      name      = "Usuarios"
      image     = "public.ecr.aws/u6b7x2c0/knowme_usuarios:latest"
      essential = true
      environment = [
            {name: "MONGO_ENDPOINT", value: aws_docdb_cluster.docdb.endpoint }
        ]
      portMappings = [
        {
          containerPort = 3000
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
}

# Task Definition Emprendimientos
resource "aws_ecs_task_definition" "service-emprendimientos" {
  family = "Emprendimientos"
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu       = 256
  memory    = 512
  container_definitions = jsonencode([
    {
      name      = "Emprendimientos"
      image     = "public.ecr.aws/u6b7x2c0/knowme_emprendimientos:latest"
      essential = true
      environment = [
            {name: "MONGO_ENDPOINT", value: aws_docdb_cluster.docdb.endpoint }
        ]
      portMappings = [
        {
          containerPort = 3001
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
}

# Load Balancer

resource "aws_lb" "load-balancer" {
  name               = "KnowMe"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.subnet-1.id,aws_subnet.subnet-2.id]
}

output "load_balancer_dns" {
  value = aws_lb.load-balancer.dns_name
  
}

# Target Group Usuarios

resource "aws_lb_target_group" "target-group" {
  name        = "tg-usuarios"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.knowme-vpc.id
  depends_on = [aws_lb.load-balancer]

  health_check {
    path = "/api/v1/usuario"
    matcher = 201
  }
}

# Target Group Emprendimiento

resource "aws_lb_target_group" "target-group-emp" {
  name        = "tg-emprendimientos"
  port        = 3001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.knowme-vpc.id
  depends_on = [aws_lb.load-balancer]

  health_check {
    path = "/api/v1/emprendimiento"
    matcher = 200
  }
}

# Listener
resource "aws_lb_listener" "backend_usuarios" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

# Listener emprendimiento
resource "aws_lb_listener" "backend_emp" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port              = "3001"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group-emp.arn
  }
}

# Service usuarios

resource "aws_ecs_service" "usuarios" {
  name            = "Usuarios"
  cluster         = aws_ecs_cluster.know-me-ecs.id
  task_definition = aws_ecs_task_definition.service-usuarios.arn
  desired_count   = 1
  launch_type = "FARGATE"
  network_configuration {
    subnets = [aws_subnet.subnet-priv-1.id,aws_subnet.subnet-priv-2.id]
    security_groups = [aws_security_group.allow_web.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target-group.arn
    container_name   = "Usuarios"
    container_port   = 3000
  }
}

# Service emprendimiento

resource "aws_ecs_service" "emprendimiento" {
  name            = "Emprendimientos"
  cluster         = aws_ecs_cluster.know-me-ecs.id
  task_definition = aws_ecs_task_definition.service-emprendimientos.arn
  desired_count   = 1
  launch_type = "FARGATE"
  network_configuration {
    subnets = [aws_subnet.subnet-priv-1.id,aws_subnet.subnet-priv-2.id]
    security_groups = [aws_security_group.allow_web.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target-group-emp.arn
    container_name   = "Emprendimientos"
    container_port   = 3001
  }
}

# S3
resource "aws_s3_bucket" "knowmefrontend" {
  bucket = "knowme-2021"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}