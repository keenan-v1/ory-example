output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "cluster_id" {
  description = "The ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "autoscaling_security_group_id" {
  description = "The ID of the autoscaling security group"
  value       = module.autoscaling_sg.security_group_id
}
