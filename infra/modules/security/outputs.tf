output "waf_acl_arn" {
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
  description = "WAF Web ACL ARN"
}
