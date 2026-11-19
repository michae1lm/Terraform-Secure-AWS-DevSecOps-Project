# My planned negative-test evidence

**Status: pending live GitHub checks.** I will run these tests on feature branches and PRs only. I will **never apply** the deliberately insecure Terraform. I will keep the PR links and screenshots once they are real.

| Test branch | Change I will make | Tool I expect to catch it | Evidence to record |
|---|---|---|---|
| `test/bad-s3-public` | Add a public S3 bucket, omit encryption | Checkov | PR + failed check |
| `test/bad-sg-ssh` | Add security group ingress `0.0.0.0/0` on port 22 | Checkov | PR + failed check |
| `test/bad-imdsv1` | Change EC2 metadata `http_tokens` to `optional` | Checkov | PR + failed check |
| `test/bad-format` | Deliberately misformat HCL | `terraform fmt -check` | PR + failed check |
| `test/bad-secret` | Commit a strictly synthetic secret-shaped string, never a real credential | Gitleaks | PR + failed check |
| `test/good-change` | Add a safe, explanatory resource tag | All scans | Passing checks + approved plan |

## My procedure

1. I create one test branch from main and make only the indicated change.
2. I check my changes to be certain I am **not** committing actual AWS keys, credentials or state.
3. I open a pull request, confirm a check fails as expected, and save a screenshot showing the tool and error.
4. I revert the insecure change and confirm the check passes before closing the PR.
5. I use a separate safe branch to prove the scan and plan behavior on a compliant change.
6. I add a short README table of observed outcomes and evidence URLs. I do not invent check IDs or test counts.

**Note:** Gitleaks may not flag every documentation placeholder because detectors depend on patterns and entropy. I will adjust the *synthetic* case if needed; the intended demonstration is not a guarantee of a particular finding.
