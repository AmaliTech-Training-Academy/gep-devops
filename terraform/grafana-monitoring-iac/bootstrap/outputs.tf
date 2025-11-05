output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  value = <<-EOT
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    region         = "${var.aws_region}"
    encrypt        = true
  EOT
}
