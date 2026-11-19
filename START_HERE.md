# My start-here checklist (Windows / PowerShell)

**This is a prepared source repository, not a live AWS deployment.** I use a dedicated personal AWS account and make sure I understand charges before applying.

1. I create a **$10 AWS Budget alert** and enable root MFA; I use a non-root SSO admin for the lab.
2. I install AWS CLI v2, Terraform >= 1.10, Git, and Python. I run `aws configure sso --profile tfsec-lab`, `aws sso login --profile tfsec-lab`, then `$env:AWS_PROFILE='tfsec-lab'`.
3. I confirm `aws sts get-caller-identity` shows **my personal account**, not school or work. I check `bootstrap/variables.tf` so my GitHub owner/repo match my account.
4. I execute these commands in the project root:

```powershell
terraform fmt -recursive
terraform -chdir=bootstrap init
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
# I inspect the plan BEFORE proceeding
terraform -chdir=bootstrap apply bootstrap.tfplan
.\scripts\configure-backend.ps1
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev validate
terraform -chdir=envs/dev plan
# I choose whether to apply only after cost and permissions review
```

5. I configure GitHub Actions variables using the four outputs shown in `README.md`. I configure a protected `production` environment with a **required reviewer**, and `main` branch protection. I run Checkov, TFLint and Gitleaks locally or review GitHub scan failures.
6. I enable my deployment only by manually entering **DEPLOY** on `main` in the GitHub workflow and then approving the environment.
7. I validate logs and resources with `scripts/verify-deployment.ps1`, run my separate auditor, and save authentic redacted screenshots / reports.
8. I turn off demo EC2/endpoints and follow `docs/costs-and-cleanup.md` when finished.

**Important:** `terraform plan` and `terraform apply` interact with paid AWS services. Terraform has NOT been run or authenticated as part of preparing this download.
