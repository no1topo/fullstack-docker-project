output "autoscaling_target_id" {
  value = aws_appautoscaling_target.ecs_target.id
}

output "cpu_scaling_policy_arn" {
  value = aws_appautoscaling_policy.ecs_policy_cpu.arn
}

output "memory_scaling_policy_arn" {
  value = aws_appautoscaling_policy.ecs_policy_memory.arn
}
