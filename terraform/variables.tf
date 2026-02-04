variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  type = string
  description = "AWS availability zone"
  default = "us-east-1a"
}