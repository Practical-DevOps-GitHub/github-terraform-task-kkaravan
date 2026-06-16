terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

data "github_repository" "repo" {
  name = var.repository_name
}

resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.repo.name
  username   = "softservedata"
  permission = "push"
}

resource "github_branch" "develop" {
  repository = data.github_repository.repo.name
  branch     = "develop"
}

resource "github_branch_default" "default" {
  repository = data.github_repository.repo.name
  branch     = github_branch.develop.branch
}

resource "github_repository_file" "codeowners" {
  repository          = data.github_repository.repo.name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  overwrite_on_create = true
  content             = "* @softservedata"
}

resource "github_repository_file" "pr_template" {
  repository          = data.github_repository.repo.name
  branch              = "main"
  file                = ".github/pull_request_template.md"
  overwrite_on_create = true
  content             = <<EOF
## Describe your changes

## Issue ticket number and link

## Checklist before requesting a review

- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update
EOF
}

resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "develop"

  enforce_admins = true

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
  }

  required_status_checks {
    strict = true
  }
}

resource "github_branch_protection" "main" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "main"

  enforce_admins = true

  required_pull_request_reviews {
    required_approving_review_count = 1
    require_code_owner_reviews      = true
    dismiss_stale_reviews           = true
  }

  required_status_checks {
    strict = true
  }
}

resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.repo.name
  title      = "DEPLOY_KEY"
  key        = file("${path.module}/deploy_key.pub")
  read_only  = false
}

resource "github_actions_secret" "pat" {
  repository      = data.github_repository.repo.name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

resource "github_actions_secret" "terraform" {
  repository      = data.github_repository.repo.name
  secret_name     = "TERRAFORM"
  plaintext_value = file("${path.module}/main.tf")
}
