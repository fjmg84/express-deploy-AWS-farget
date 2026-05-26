variable "environment" {}
variable "project" {}
variable "alb_dns_name" {
  description = "DNS name of the ALB to forward requests to"
  type        = string
}
