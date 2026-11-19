# My AWS cost and teardown procedure

I treat this as a billable AWS project, not a free sandbox. An AWS Budget sends notifications but **does not stop spending**. Before deployment I configure a $10 monthly budget and monitor actual usage.

## Cost drivers I monitor

- KMS customer-managed keys: recurring monthly charges per active key, with request charges possible.
- GuardDuty: billed after applicable trial, according to log volume and selected features.
- CloudWatch logs: ingestion, storage and monitoring.
- S3: stored state/logs, versions, and requests.
- Three optional SSM **interface** endpoints: hourly endpoint costs and data processing, even without EC2 traffic.
- Optional EC2 t3.micro and EBS: instance uptime, storage, and other applicable charges.
- No NAT gateway or internet gateway is created.

**I verify live prices using the [AWS pricing calculator](https://calculator.aws/) and my account's billing console rather than rely on a fixed price estimate.**

## Controlled demonstration

1. I run `terraform -chdir=envs/dev plan` and inspect all billable resources and changes.
2. I keep `enable_compute=false` and `enable_private_endpoints=false` until an SSM demo is necessary.
3. For the demo, I temporarily set `enable_compute=true` and apply, then use `aws ssm start-session --target INSTANCE_ID` after the agent connects.
4. I turn the demo flag off and apply again, ensuring both EC2 and interface endpoints have been removed.
5. I check my actual billing dashboard and endpoints list after the demo.

## Teardown (AWS administrator, deliberate)

```powershell
# From repository root, with AWS_PROFILE targeting the dedicated lab account
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev plan -destroy
terraform -chdir=envs/dev destroy
```

**Versioned buckets will not destroy if nonempty.** I first verify I no longer need their logs, then explicitly empty **all object versions and delete markers** using the AWS Console or a carefully scoped AWS CLI command. I do not turn on `force_destroy` by default because audit logs should not be deleted casually. I rerun `terraform destroy` after the buckets are empty.

Only after dev state resources are gone do I handle bootstrap state. I back up the local bootstrap `.tfstate` securely, remove remaining dev state versions from the state bucket when safe, and then run `terraform -chdir=bootstrap plan -destroy` and `terraform -chdir=bootstrap destroy`. Any remaining logs/access-log versions may need separate manual emptying; **never delete state required to destroy resources**.

**KMS deletion has a waiting period**, so key deletion can remain scheduled even after Terraform returns. I audit all remaining AWS resources and billing afterward. The repository, docs and screenshots stay available for recruiters without a live billable environment.
