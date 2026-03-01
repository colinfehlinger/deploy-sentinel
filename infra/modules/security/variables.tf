variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_waf" {
  description = "Enable WAF Web ACL for ALB"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
