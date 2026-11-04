# CPS 5981 Lab 11 - Infrastructure-as-Code Assurance (starter)

**Question for this lab:** who can change what reaches production, and does that require review?

Everything here runs free on a **public** GitHub repository. No cloud account, token or card is needed:
the Terraform in `iac/aws` and `iac/gcp` is **scanned, never applied**. Follow the interactive lab page
your instructor posted; it walks every station with direct links.

| Path | What it is |
|---|---|
| `iac/aws/main.tf`, `iac/gcp/main.tf` | The same Cougar Advising infrastructure declared for AWS and for Google Cloud, with insecure defaults |
| `iac/local/main.tf` | The **declared** state of the lab target (a single-tenant, local deployment) |
| `deployed/` | The **deployed** state: what is actually running. Editing it is the lab's stand-in for a console change |
| `.github/workflows/iac-assurance.yml` | The pipeline: Checkov scans `iac/`, zizmor scans the pipeline itself, the gate decides |
| `.github/workflows/drift-check.yml` | Compares declared with deployed, weekly and on demand |
| `gate/evaluate.py`, `gate-policy.md` | The gate, and the only file it reads |
| `.github/CODEOWNERS` | Who must review changes to the pipeline, the gate and the infrastructure |
| `submission/` | Where your deliverables go |

The pipeline in this starter is itself insecure. Finding out how is part of the lab.

**Do not** add real cloud credentials to this repository, ever. The lab never needs them.
