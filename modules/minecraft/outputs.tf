output "server_ip" {
  description = "Elastic IP of the Minecraft server"
  value       = aws_eip.minecraft.public_ip
}

output "instance_id" {
  description = "EC2 instance ID (use for start/stop)"
  value       = aws_instance.minecraft.id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i minecraft-key.pem ec2-user@${aws_eip.minecraft.public_ip}"
}

output "minecraft_address" {
  description = "Address to connect in Minecraft"
  value       = "${aws_eip.minecraft.public_ip}:25565"
}

output "start_server" {
  description = "Command to start the server"
  value       = "aws ec2 start-instances --instance-ids ${aws_instance.minecraft.id} --region ${var.region}"
}

output "stop_server" {
  description = "Command to stop the server"
  value       = "aws ec2 stop-instances --instance-ids ${aws_instance.minecraft.id} --region ${var.region}"
}
