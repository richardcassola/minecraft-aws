resource "aws_iam_role" "minecraft" {
  name = "${var.server_name}-role"

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

  tags = {
    Name = "${var.server_name}-role"
  }
}

resource "aws_iam_role_policy" "minecraft_s3" {
  name = "${var.server_name}-s3-backup"
  role = aws_iam_role.minecraft.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.minecraft_backup.arn,
        "${aws_s3_bucket.minecraft_backup.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "minecraft_ec2" {
  name = "${var.server_name}-ec2-shutdown"
  role = aws_iam_role.minecraft.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StopInstances",
        "ec2:DescribeInstances"
      ]
      Resource = ["arn:aws:ec2:*:*:instance/*"]
      Condition = {
        StringEquals = {
          "ec2:ResourceTag/Name" = var.server_name
        }
      }
    }]
  })
}

resource "aws_iam_instance_profile" "minecraft" {
  name = "${var.server_name}-profile"
  role = aws_iam_role.minecraft.name
}
