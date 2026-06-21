output "app_id" {
  description = "Amplify app ID."
  value       = aws_amplify_app.dashboard.id
}

output "default_domain" {
  description = "Amplify default domain."
  value       = aws_amplify_app.dashboard.default_domain
}

output "app_url" {
  description = "Amplify app URL for the branch."
  value = format(
    "https://%s.%s",
    aws_amplify_branch.dashboard.branch_name,
    aws_amplify_app.dashboard.default_domain
  )
}
