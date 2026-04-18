resource "aws_instance" "minecraft" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
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
    bucket_name    = aws_s3_bucket.minecraft_backup.bucket
    whitelist_json = jsonencode([for name in var.whitelist_players : { name = name }])
  })

  tags = {
    Name = var.server_name
  }
}
