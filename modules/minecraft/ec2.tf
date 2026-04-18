resource "tls_private_key" "minecraft" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "minecraft" {
  key_name   = "${var.server_name}-key"
  public_key = tls_private_key.minecraft.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.minecraft.private_key_openssh
  filename        = "${path.module}/../../minecraft-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "minecraft" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.minecraft.key_name
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  iam_instance_profile   = aws_iam_instance_profile.minecraft.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../../scripts/setup.sh", {
    bucket_name = aws_s3_bucket.minecraft_backup.bucket
  })

  tags = {
    Name = var.server_name
  }
}
