# My AWS security control mapping

I mapped the following **control areas** to the Terraform resources I authored. These are **not verified CIS benchmark IDs**. Before claiming benchmark alignment in a resume, I will obtain an authorized copy of the applicable CIS AWS Foundations Benchmark version, record the version, and verify the specific ID-to-control matches.

| Security control area | Code I wrote | What I will verify |
|---|---|---|
| Multi-region trail and log validation | `modules/logging/aws_cloudtrail.main` | Trail status/log delivery/validation |
| CloudTrail KMS encryption | `modules/logging/aws_kms_key.logs` | Trail key ARN and policy |
| CloudTrail monitoring | CloudWatch log group and trail IAM role | Events actually appear in CloudWatch |
| S3 public access denied | `account-baseline`, `secure-s3`, bootstrap | Account/bucket policy status |
| S3 TLS-only access | `aws_iam_policy_document` + bucket policies | Deny HTTP requests |
| State confidentiality and recovery | Bootstrap KMS/versioning/access logs/locking | S3 object versions and allowed principals |
| EBS encryption | `aws_ebs_encryption_by_default`, `aws_ebs_default_kms_key` | AWS API and instance EBS volume |
| IAM password policy | `aws_iam_account_password_policy` | AWS account setting |
| VPC flow logs | `aws_flow_log.all` | Captured records in CloudWatch |
| Default VPC security group | `aws_default_security_group.restricted` | No ingress/egress rules |
| Instance metadata protection | `http_tokens = "required"` | IMDSv1 request rejected |
| Threat detection | `aws_guardduty_detector` | Detector enabled, relevant features |
| CI security gates | GitHub workflow scans | Negative PR tests actually fail |

I will not claim an auditor control is passing just because I wrote a Terraform resource; I will verify the deployed resource and capture evidence first.
