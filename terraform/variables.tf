variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_tag" {
  description = "Project tag value applied to all resources"
  type        = string
  default     = "karatu-2025-capstone"
}

variable "student_id" {
  description = "Student ID used for unique S3 bucket naming"
  type        = string
  default     = "alt-soe-025-3333"
}
