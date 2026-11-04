"""CPS 5981 Unit 11 gate. Reads ONLY gate-policy.md and the raw scanner output in run-output/.
Decides block / warn / record for every finding and fails the run if anything blocks.
Order for each finding: (1) an exception naming this exact finding and still in date,
(2) the first rule that matches its source and check or level, (3) the policy default.
Missing or unreadable scanner output blocks the run: a check that did not run is not a check that passed."""
import json, os, re, sys, datetime, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "run-output"
today = datetime.date.today().isoformat()

def policy():
    text = (ROOT / "gate-policy.md").read_text()
    m = re.search(r"```json\s*(\{.*?\})\s*```", text, re.S)
    if not m: sys.exit("gate-policy.md has no ```json policy block")
    return json.loads(m.group(1))

def checkov(missing):
    p = OUT / "checkov.json"
    try: data = json.loads(p.read_text())
    except Exception: missing.append("checkov.json"); return []
    data = data if isinstance(data, list) else [data]
    found = []
    for r in data:
        for c in (r.get("results") or {}).get("failed_checks", []):
            found.append({"source": "checkov", "check": c["check_id"], "level": (c.get("severity") or "unrated").lower(),
                          "resource": c["resource"], "where": f'{c["file_path"].lstrip("/")}:{c["file_line_range"][0]}',
                          "title": c["check_name"]})
    return found

def zizmor(missing):
    p = OUT / "zizmor.json"
    try: data = json.loads(p.read_text())
    except Exception: missing.append("zizmor.json"); return []
    found = []
    for f in data:
        loc = f["locations"][0]; path = list(loc["symbolic"]["key"].get("Local", {}).values() or ["?"])[0]
        row = loc["concrete"]["location"]["start_point"]["row"] + 1
        found.append({"source": "zizmor", "check": f["ident"], "level": f["determinations"]["severity"].lower(),
                      "resource": f"{path}:{row}", "where": f"{path}:{row}", "title": f["desc"]})
    return found

def decide(f, P):
    for e in P.get("exceptions", []):
        if e.get("source") == f["source"] and e.get("check") == f["check"] and e.get("resource") == f["resource"]:
            if e.get("expires", "9999-12-31") >= today:
                return e.get("decision", "record"), f'exception: {e.get("reason", "")} (approved by {e.get("approver", "?")}, expires {e.get("expires", "never")})'
    for r in P.get("rules", []):
        if r.get("source") not in (None, f["source"]): continue
        if "check" in r and r["check"] != f["check"]: continue
        if "level" in r and r["level"] != f["level"]: continue
        return r["decision"], f'rule: {r.get("why", r.get("check") or r.get("level"))}'
    return P.get("default", "block"), "default"

P = policy(); missing = []
findings = checkov(missing) + zizmor(missing)
rows = []
for f in findings:
    d, why = decide(f, P); rows.append((d, f, why))
order = {"block": 0, "warn": 1, "record": 2}
rows.sort(key=lambda x: (order.get(x[0], 0), x[1]["source"], x[1]["check"]))
count = {k: sum(1 for d, _, _ in rows if d == k) for k in order}
blocked = count["block"] > 0 or bool(missing)

lines = [f"# Gate decision: {'BLOCKED' if blocked else 'PASSED'}", "",
         "| Item | Value |", "|---|---|",
         f"| Policy version | {P.get('version', '?')} |", f"| Policy owner | {P.get('owner', '?')} |",
         f"| Run ID | {os.environ.get('GITHUB_RUN_ID', 'local')} |", f"| Commit | {os.environ.get('GITHUB_SHA', 'local')} |",
         f"| Findings | {len(rows)} (block {count['block']}, warn {count['warn']}, record {count['record']}) |", ""]
if missing:
    lines += [f"**Missing evidence:** {', '.join(missing)}. The run blocks: a check that did not run is not a check that passed.", ""]
lines += ["| Decision | Source | Check | Resource | Finding | Why |", "|---|---|---|---|---|---|"]
for d, f, why in rows:
    lines.append(f"| {d.upper()} | {f['source']} | {f['check']} | `{f['resource']}` | {f['title']} | {why} |")
lines += ["", "_A clean run is not evidence of assurance. It is evidence that these checks did not fire._"]
report = "\n".join(lines)
OUT.mkdir(exist_ok=True); (OUT / "gate-decision.md").write_text(report)
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as s: s.write(report + "\n")
print(report)
sys.exit(1 if blocked else 0)
