# Actual project status — 2026-11-18

- [x] Terraform source for bootstrap, state storage, OIDC roles and secure AWS infrastructure
- [x] GitHub Actions scan / plan / explicit manual apply workflow
- [x] PowerShell and Bash remote backend setup scripts
- [x] First-person README, threat model, control mapping and negative-test plan
- [x] Offline structural test suite authored
- [ ] Install Terraform, run `terraform fmt -recursive` then `terraform fmt -check -recursive`
- [ ] Run `terraform init -backend=false` and `terraform validate` with downloaded providers
- [ ] Run TFLint, Checkov and Gitleaks, fix/document resulting findings
- [ ] Run an AWS bootstrap plan/apply in the dedicated account
- [ ] Configure GitHub repository variables and production environment reviewers
- [ ] Complete PR negative tests and SHA-pin Actions
- [ ] Deploy, test CloudTrail/SSM/GuardDuty, and run read-only AWS auditor
- [ ] Save sanitized evidence and actual numbers; narrow apply IAM permissions
- [ ] Destroy chargeable resources after demo

**This is not a claim that AWS resources have been created.** Actual testing requires the tools and authenticated account. Local Python structural tests only test repository structure and explicit safety settings.
