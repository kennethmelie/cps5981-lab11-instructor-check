# Gate policy - Cougar Advising infrastructure

This file is the **only** thing the gate reads. It records what this organization considers
unacceptable in its infrastructure and its pipeline. Change it by pull request, like code.

## Starter policy (0.1.0)

Everything warns. Nothing blocks. Nobody owns it. In Station 5 you replace this with a policy
you can defend: what blocks, what warns, what is recorded, a named owner, and at least two
real findings that should **not** block release here, each with its reason.

```json
{
  "version": "0.1.0",
  "owner": "UNASSIGNED",
  "default": "warn",
  "rules": [],
  "exceptions": []
}
```

## How the gate reads this

1. An **exception** naming this exact finding (`source`, `check`, `resource`) that has not expired.
2. Otherwise the first **rule** whose `source` matches and whose `check` or `level` matches.
3. Otherwise the **default**.

Missing scanner output always blocks. Exceptions name one finding; they never excuse a whole check.
