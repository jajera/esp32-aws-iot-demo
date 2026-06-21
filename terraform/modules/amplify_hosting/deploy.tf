locals {
  web_deploy_files = concat(
    [for f in fileset("${var.repo_root}/web/src", "**/*") : "src/${f}"],
    [for f in fileset("${var.repo_root}/web/public", "**/*") : "public/${f}"],
    ["index.html", "package.json", "package-lock.json"],
  )
  web_source_hash = sha256(join("", [
    for f in local.web_deploy_files : filesha256("${var.repo_root}/web/${f}")
  ]))
}

resource "terraform_data" "amplify_deploy" {
  count = var.deploy_amplify_on_apply ? 1 : 0

  triggers_replace = [
    var.api_base_url,
    local.web_source_hash,
  ]

  depends_on = [
    aws_amplify_app.dashboard,
    aws_amplify_branch.dashboard,
  ]

  provisioner "local-exec" {
    command     = "${var.repo_root}/scripts/deploy-amplify.sh"
    working_dir = var.repo_root
    environment = {
      AMPLIFY_APP_ID = aws_amplify_app.dashboard.id
      AMPLIFY_BRANCH = aws_amplify_branch.dashboard.branch_name
      VITE_API_URL   = var.api_base_url
      AWS_REGION     = var.aws_region
    }
  }
}
