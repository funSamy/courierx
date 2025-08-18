# Data source to dynamically find the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create an SSH Key Pair from the provided public key
resource "aws_key_pair" "deployer" {
  key_name   = "courierx-deployer-key"
  public_key = var.ssh_public_key

  tags = var.tags
}

# Security Group to allow mail and SSH traffic
resource "aws_security_group" "mail_server_sg" {
  name        = "courierx-mail-server-sg"
  description = "Allow SMTP, IMAP, and SSH traffic for CourierX mail server"

  # SSH access (restrict to your IP for better security)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to the world. Restrict to your IP if possible.
  }

  # SMTP
  ingress {
    description = "SMTP"
    from_port   = 25
    to_port     = 25
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SMTP Submission (TLS)
  ingress {
    description = "SMTP Submission"
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IMAPS
  ingress {
    description = "IMAPS"
    from_port   = 993
    to_port     = 993
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "courierx-mail-server-sg" }
  )
}

# Elastic IP for a stable, public-facing address
resource "aws_eip" "mail_server_ip" {
  domain = "vpc"

  tags = merge(
    var.tags,
    { Name = "courierx-mail-server-eip" }
  )
}

# The EC2 instance running the mail server
resource "aws_instance" "mail_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  vpc_security_group_ids = [aws_security_group.mail_server_sg.id]

  # Use templatefile to pass variables to the user-data script
  user_data = templatefile("${path.module}/user_data.sh", {
    domain_name  = var.domain_name
    noreply_pass = var.noreply_pass
    support_pass = var.support_pass
    forward_to   = var.forward_to
  })

  # Ensure proper startup time
  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    { Name = "${var.domain_name}-mail-server" }
  )
}

# Associate the Elastic IP with the instance
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.mail_server.id
  allocation_id = aws_eip.mail_server_ip.id
}
