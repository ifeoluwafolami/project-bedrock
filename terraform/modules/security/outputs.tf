output "dev_view_access_key_id"     { value = aws_iam_access_key.dev_view.id }
output "dev_view_secret_access_key" {
  value     = aws_iam_access_key.dev_view.secret
  sensitive = true
}
output "dev_view_console_password" {
  value     = aws_iam_user_login_profile.dev_view.password
  sensitive = true
}
output "dev_view_console_url" {
  value = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}
