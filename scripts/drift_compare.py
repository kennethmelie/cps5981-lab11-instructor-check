"""Compare DECLARED state (rendered by Terraform) with DEPLOYED state (exported from the target).
Usage: python3 drift_compare.py DECLARED_DIR DEPLOYED_DIR
Exit code 0 = no drift, 2 = drift found, 1 = a side is missing (that blocks too: no evidence is not a pass)."""
import json, pathlib, sys

dec, dep = (pathlib.Path(p) for p in sys.argv[1:3])

def load(p):
    try:
        return json.loads(p.read_text())
    except Exception as e:
        return {"__unreadable__": str(e)}

def walk(a, b, path, out):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in b: out.append(("declared, not deployed", f"{path}.{k}", a[k], None))
            elif k not in a: out.append(("deployed, not declared", f"{path}.{k}", None, b[k]))
            else: walk(a[k], b[k], f"{path}.{k}", out)
    elif isinstance(a, list) and isinstance(b, list):
        key = lambda x: json.dumps(x, sort_keys=True)
        A = {key(x): x for x in a}; B = {key(x): x for x in b}
        for k in A.keys() - B.keys(): out.append(("declared, not deployed", f"{path}[]", A[k], None))
        for k in B.keys() - A.keys(): out.append(("deployed, not declared", f"{path}[]", None, B[k]))
    elif a != b:
        out.append(("value differs", path, a, b))

files = sorted({p.name for p in dec.glob("*.json")} | {p.name for p in dep.glob("*.json")})
rows, missing = [], []
for f in files:
    a, b = dec / f, dep / f
    if not a.exists(): rows.append(("deployed, not declared", f, None, "whole file")); continue
    if not b.exists(): missing.append(f); continue
    out = []; walk(load(a), load(b), f, out); rows += out

print("# Drift report\n")
print(f"Declared: `{dec}/` (rendered from iac/local by Terraform). Deployed: `{dep}/`.\n")
if missing:
    print(f"**BLOCKED: no deployed evidence for {', '.join(missing)}.** A check that cannot see the target has not passed.\n")
if not rows and not missing:
    print("**No drift.** Every deployed setting matches the declaration.")
    sys.exit(0)
if rows:
    print(f"**DRIFT: {len(rows)} divergence(s).** Each one has a story. Find it, then reconcile: declare it, or revert it.\n")
    print("| Kind | Where | Declared | Deployed |\n|---|---|---|---|")
    for kind, where, a, b in rows:
        fmt = lambda v: "-" if v is None else "`" + json.dumps(v) + "`"
        print(f"| {kind} | `{where}` | {fmt(a)} | {fmt(b)} |")
sys.exit(1 if missing else 2)
