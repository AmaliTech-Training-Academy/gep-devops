# ==============================================================================
# Grafana Monitoring Outputs
# ==============================================================================

output "grafana_url" {
  description = "Grafana monitoring dashboard URL"
  value       = module.grafana_monitor.grafana_url
}

output "grafana_instance_id" {
  description = "Grafana EC2 instance ID"
  value       = module.grafana_monitor.grafana_instance_id
}

output "grafana_instance_private_ip" {
  description = "Grafana EC2 instance private IP"
  value       = module.grafana_monitor.grafana_instance_private_ip
  sensitive   = true
}


# ==============================================================================
# Next Steps Instructions
# ==============================================================================

output "next_steps" {
  description = "Deployment next steps"
  value       = <<-EOT
    ========================================
    INFRASTRUCTURE DEPLOYMENT COMPLETE!
    ========================================

        Grafana Monitoring
    
     Access Points:
    Grafana Monitoring: ${module.grafana_monitor.grafana_url}
    
    
  EOT
}