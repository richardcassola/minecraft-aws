resource "aws_security_group" "minecraft" {
  name        = "${var.server_name}-sg"
  description = "Security group for Minecraft server"

  ingress {
    description = "Minecraft Java Edition"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.server_name}-sg"
  }
}

resource "aws_eip" "minecraft" {
  instance = aws_instance.minecraft.id

  tags = {
    Name = "${var.server_name}-eip"
  }
}
