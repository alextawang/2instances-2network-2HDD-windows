provider "aws" {
  region = "us-west-2"  # Replace with your desired AWS region
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnets (one for public, one for private)
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "192.168.200.0/24"
}

# Create Internet Gateway for Public Instances
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a route table and associate it with the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group (Allowing RDP and other necessary protocols)
resource "aws_security_group" "windows_sg" {
  name        = "allow_rdp"
  description = "Allow RDP traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3389
    to_port     = 3389
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

# AMI for Windows Server (Make sure this matches a Windows AMI in your region)
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]  # Windows AMI owner

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

# Create the first Windows instance (imudssw-alen001)
resource "aws_instance" "imudssw_alen001" {
  ami                    = data.aws_ami.windows.id
  instance_type          = "t2.micro"
  key_name               = "rsa-west-private"  # Replace with your key pair
  subnet_id              = aws_subnet.public_subnet.id
  security_groups        = [aws_security_group.windows_sg.name]
  associate_public_ip_address = true
  availability_zone      = "us-west-2"

  tags = {
    Name = "imudssw-alen001"
  }

  # Root Block Device
  root_block_device {
    volume_size = 30
  }

  # Additional EBS Volume 1 (20 GB)
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 20
  }

  # Additional EBS Volume 2 (20 GB)
  ebs_block_device {
    device_name = "/dev/sdc"
    volume_size = 20
  }
}

# Create the second Windows instance (imudssw-alxp001)
resource "aws_instance" "imudssw_alxp001" {
  ami                    = data.aws_ami.windows.id
  instance_type          = "t2.micro"
  key_name               = "rsa-west-private"  # Replace with your key pair
  subnet_id              = aws_subnet.private_subnet.id
  security_groups        = [aws_security_group.windows_sg.name]
  associate_public_ip_address = false
  availability_zone      = "us-west-2"

  tags = {
    Name = "imudssw-alxp001"
  }

  # Root Block Device
  root_block_device {
    volume_size = 30
  }

  # Additional EBS Volume 1 (10 GB)
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 10
  }

  # Additional EBS Volume 2 (10 GB)
  ebs_block_device {
    device_name = "/dev/sdc"
    volume_size = 10
  }
}

# Add IAM role (optional if needed for the domain)
resource "aws_iam_role" "windows_domain_join" {
  name = "Windows_Domain_Join_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "windows_profile" {
  name = "windows_instance_profile"
  role = aws_iam_role.windows_domain_join.name
}
