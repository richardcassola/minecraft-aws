output "server_ip" {
  description = "Elastic IP of the Minecraft server"
  value       = module.minecraft.server_ip
}

output "instance_id" {
  description = "EC2 instance ID (use for start/stop)"
  value       = module.minecraft.instance_id
}

output "ssm_command" {
  description = "Command to connect to the server via SSM"
  value       = module.minecraft.ssm_command
}

output "minecraft_address" {
  description = "Address to connect in Minecraft"
  value       = module.minecraft.minecraft_address
}

output "start_server" {
  description = "Command to start the server"
  value       = module.minecraft.start_server
}

output "stop_server" {
  description = "Command to stop the server"
  value       = module.minecraft.stop_server
}
