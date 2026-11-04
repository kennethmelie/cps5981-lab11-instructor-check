# Gate policy - Cougar Advising infrastructure

This file is the **only** thing the gate reads. It records what this organization considers
unacceptable in its infrastructure and its pipeline. Change it by pull request, like code.
Owner: Dr. Kenneth Melie (reference solution). Version 1.0.0.

## What blocks, and why

- **Anything not decided below** (default block). Nothing passes because nobody thought about it.
- **Pipeline findings of high or medium severity** (zizmor). The pipeline holds production
  credentials and runs contributor code; an injectable or over-privileged workflow is a production risk.
- **Every Checkov finding not named below**: public data, wildcard IAM, open SSH, unrestricted
  pipeline trust, disabled audit logging, unencrypted disks.

## What is recorded, and why (conventional advice that does not matter here)

| Check | Decision | Reason |
|---|---|---|
| CKV_AWS_144 cross-region replication | record | Exports are rebuilt nightly from the source database; replicating a rebuildable copy buys nothing. |
| CKV2_AWS_62 S3 event notifications | record | No consumer subscribes to bucket events; notifications would go nowhere. |
| CKV_AWS_145, CKV_AWS_35, CKV_GCP_38 customer-managed keys | record | Provider-managed encryption at rest meets the objective for a single-tenant system. A customer-managed key separates tenants we do not have. Revisit if a second tenant is added. |
| CKV2_AWS_61 lifecycle, CKV_AWS_252 SNS, CKV2_AWS_10 CloudWatch | warn | Wanted but not decided or built. They stay visible in every pull request until they are. |

## Exceptions (one exact finding each)

- `CKV_AWS_126` on `aws_instance.web`: basic five-minute metrics suffice for one server; detailed monitoring is a paid feature.
- `CKV_GCP_62` on `google_storage_bucket.exports`: data access is already logged by Cloud Audit Logs (DATA_READ, DATA_WRITE).

```json
{
  "version": "1.0.0",
  "owner": "Dr. Kenneth Melie (reference solution)",
  "default": "block",
  "rules": [
    {"source": "zizmor", "level": "high", "decision": "block", "why": "injectable or over-privileged pipeline"},
    {"source": "zizmor", "level": "medium", "decision": "block", "why": "pipeline credential exposure"},
    {"source": "zizmor", "level": "low", "decision": "warn", "why": "pipeline hygiene"},
    {"source": "zizmor", "level": "informational", "decision": "record", "why": "pipeline note"},
    {"source": "checkov", "check": "CKV_AWS_144", "decision": "record", "why": "single region by design: exports are rebuildable"},
    {"source": "checkov", "check": "CKV2_AWS_62", "decision": "record", "why": "no consumer for bucket events"},
    {"source": "checkov", "check": "CKV_AWS_145", "decision": "record", "why": "provider-managed keys suffice, single tenant"},
    {"source": "checkov", "check": "CKV_AWS_35", "decision": "record", "why": "provider-managed keys suffice, single tenant"},
    {"source": "checkov", "check": "CKV_GCP_38", "decision": "record", "why": "provider-managed keys suffice, single tenant"},
    {"source": "checkov", "check": "CKV2_AWS_61", "decision": "warn", "why": "retention not yet set by the records schedule"},
    {"source": "checkov", "check": "CKV_AWS_252", "decision": "warn", "why": "audit alerting wanted, not built"},
    {"source": "checkov", "check": "CKV2_AWS_10", "decision": "warn", "why": "audit alerting wanted, not built"}
  ],
  "exceptions": [
    {"source": "checkov", "check": "CKV_AWS_126", "resource": "aws_instance.web", "decision": "record",
     "reason": "basic five-minute metrics suffice for one server; detailed monitoring is paid",
     "approver": "Dr. Kenneth Melie", "expires": "2026-12-31"},
    {"source": "checkov", "check": "CKV_GCP_62", "resource": "google_storage_bucket.exports", "decision": "record",
     "reason": "data access already logged by Cloud Audit Logs DATA_READ and DATA_WRITE",
     "approver": "Dr. Kenneth Melie", "expires": "2026-12-31"}
  ]
}
```

## How the gate reads this

1. An **exception** naming this exact finding (`source`, `check`, `resource`) that has not expired.
2. Otherwise the first **rule** whose `source` matches and whose `check` or `level` matches.
3. Otherwise the **default**.

Missing scanner output always blocks. Exceptions name one finding; they never excuse a whole check.
