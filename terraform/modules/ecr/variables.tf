# # ==============================================================================
# # terraform/modules/ecr/variables.tf
# # ==============================================================================

# variable "project_name" {
#   description = "Project name for resource naming"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "cicd_role_arns" {
#   description = "IAM role ARNs for CI/CD access"
#   type        = list(string)
#   default     = []
# }

# variable "enable_replication" {
#   description = "Enable cross-region replication"
#   type        = bool
#   default     = false
# }

# variable "replication_region" {
#   description = "Region for replication"
#   type        = string
#   default     = "us-west-2"
# }

# variable "tags" {
#   description = "Additional tags"
#   type        = map(string)
#   default     = {}
# }

