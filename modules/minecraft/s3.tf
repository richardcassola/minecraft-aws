resource "aws_s3_bucket" "minecraft_backup" {
  bucket = "${var.server_name}-backups-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.server_name}-backups"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_expiration" {
  bucket = aws_s3_bucket.minecraft_backup.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "minecraft_backup" {
  bucket = aws_s3_bucket.minecraft_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "minecraft_backup" {
  bucket                  = aws_s3_bucket.minecraft_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
