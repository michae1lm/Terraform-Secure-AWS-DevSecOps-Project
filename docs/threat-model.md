# My threat model

I assume that my developer laptop, GitHub workflows, AWS identity, IaC state, and deployed AWS resources are potential attack surfaces. My primary security objectives are to prevent accidental exposure, protect administrative credentials, preserve audit evidence, and make unreviewed infrastructure changes harder.

| Threat I considered | Control I implemented | Residual risk / verification |
|---|---|---|
| Credentials committed to GitHub | OIDC short-lived sessions; Gitleaks scanning | Malicious insider or workflow may misuse issued credentials; review access and token permissions |
| Fork PR tries to obtain plan credentials | Plan job skips fork PRs, OIDC audience and subject checks | Same-repository PR contributors remain trusted; minimize write access |
| Malicious code change triggers a deployment | Checkov, format, TFLint, manual `DEPLOY`, protected environment | Environment review must be configured; scanners are imperfect |
| Attacker changes CI trust role | Bootstrap-owned OIDC roles in separate Terraform state | Bootstrap administrators still can alter roles; require MFA |
| AWS state file disclosure or deletion | S3 block public access, KMS, versioning, TLS deny, access logging, key-scoped state permissions | Terraform state may store secrets; never publish it; monitor access and retention |
| Public SSH / compromised instance credentials | No public IP, no SSH ingress, required IMDSv2, SSM-managed instance | An attacker already in VPC can reach endpoint HTTPS; restrict principals and patch AMI |
| CloudTrail tampering / log erasure | Multi-region trail, log validation, KMS, versioned S3 | Same-account privileged admin can disable logging; organizations/object lock would be stronger |
| Public S3 data exposure | Account and bucket public-access-block, TLS-only policies | Private credentials can still read data if IAM is too permissive |
| Untracked VPC activity | VPC Flow Logs with KMS-encrypted CloudWatch log group | Flow logs are metadata, not packet content; validate capture and retention |
| Cost abuse | Budget alerts, no NAT, disabled-by-default EC2/paid endpoints | Alerts do not cap billing, GuardDuty/KMS/CloudWatch may still cost money |
| Compromised GitHub Action | Dependabot and intended SHA pinning | Versions are currently tag-pinned; full SHA migration remains pending |
| Overly powerful apply role | Bootstrap separation; apply trust requires production environment | PowerUserAccess is still overly broad; tighten after a measured deploy |

## Boundaries I enforce

- **Bootstrap plane:** I run it locally with a personal administrator identity; it owns state and OIDC roles. It is not in the CI-managed dev state.
- **Plan plane:** OIDC permissions are read-oriented and state-lock aware. Fork PRs are denied AWS access.
- **Apply plane:** A separate OIDC identity is trusted only for the `production` environment. It cannot create its own GitHub OIDC roles through its scoped IAM extras.
- **Workload plane:** VPC has no IGW/NAT. Private EC2 is opt-in and uses SSM (no key pairs).

## What I still need to prove

I will inspect CloudTrail log delivery and digest validation, actual S3 policies, VPC flow logs, IAM role policies, Gitleaks/Checkov failures, and an auditor diff. I will link evidence only once those steps happen.
