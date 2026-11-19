# Scanner exceptions and hardening backlog

I will record each actual Checkov exception here with its check ID, affected file/resource, risk explanation, and compensating control. **I have not performed a full Checkov run yet**, so I do not claim any passes or formally approved skips.

Known design decisions to evaluate when I run the scanner:

| Item | Why I made this choice | Next step |
|---|---|---|
| Access-log destination does not itself have server access logging | Logging a log destination recursively increases complexity and cost | Review scanner results; document any narrow skip |
| State/log bucket replication is not enabled | Lab is single-account/region and optimized for cost | Reassess if I expand to production |
| GuardDuty can incur charges | Deliberate detection baseline | Validate cost alerts and available trial |
| Actions currently use tags rather than full SHAs | Simpler source scaffold | Resolve and pin SHA for each action |
| Apply role uses PowerUserAccess | Initial bootstrap policy to get service deployment working | Record CloudTrail events, tighten by resource and service |
| IAM password policy/ EBS defaults are account-wide | Demonstration of baseline governance | Use only a dedicated personal account |
| Multi-region CloudTrail with a home region | Trails cover all regions but logging resources are centralized | Verify other-region events are received |

I will never silently suppress HIGH/CRITICAL findings. Every exception must have a reason and be reviewed before a live apply.
