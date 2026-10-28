import json
import os

def analyze_failures():
    stats_path = "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_stats.json"
    if not os.path.exists(stats_path):
        print(f"Error: {stats_path} not found.")
        return

    with open(stats_path, "r") as f:
        stats = json.load(f)

    cases = stats.get("cases", [])
    failures = [c for c in cases if not c.get("passed", False)]

    print(f"==================================================")
    print(f"AURA Memory Evaluation Failure Analysis ({len(failures)} failures)")
    print(f"==================================================")

    # Classifications
    disclaimers = 0
    identity_confusion = 0
    omissions = 0
    other = 0

    identity_keywords = ["aura", "adaptive unified", "responsive agent"]
    disclaimer_keywords = ["don't have", "do not have", "don't know", "can't recall", "memory database", "no access", "cannot access"]

    detailed_examples = []

    for c in failures:
        got = c.get("got", "").lower()
        expected = [e.lower() for e in c.get("expected", [])]
        
        # 1. Identity/Pronoun Confusion
        is_identity = any(ik in got for ik in identity_keywords) and "name" in c.get("query", "").lower()
        # 2. Disclaimer / Refusal
        is_disclaimer = any(dk in got for dk in disclaimer_keywords) or len(got.strip()) > 150 and "don't" in got
        # 3. Partial Recall / Omissions
        # (e.g. contains name but not preference)
        found_some = any(e in got for e in expected)
        found_none = not any(e in got for e in expected)

        if is_identity:
            identity_confusion += 1
            category = "Identity/Pronoun Confusion (Model gave its own name/AURA instead of user name)"
        elif is_disclaimer:
            disclaimers += 1
            category = "Disclaimer Refusal (Model defaulted to 'I don't have access' standard safety phrase)"
        elif found_some:
            omissions += 1
            category = "Partial Recall (Model retrieved some facts but omitted others, e.g. name but not preference)"
        else:
            other += 1
            category = "Complete Miss / Alternative Phrasing (Model failed to output any expected keywords)"

        detailed_examples.append({
            "id": c["id"],
            "category_name": c["category"],
            "query": c["query"],
            "expected": c["expected"],
            "got": c["got"],
            "error_type": category
        })

    # Print results
    total_failures = len(failures)
    print(f"Failure Mode Breakdown:")
    print(f"  1. Partial Recall (Omission)     : {omissions:<3} ({omissions/total_failures*100.2:.1f}%)")
    print(f"  2. Identity/Pronoun Confusion    : {identity_confusion:<3} ({identity_confusion/total_failures*100.0:.1f}%)")
    print(f"  3. Disclaimer/Safety Refusal     : {disclaimers:<3} ({disclaimers/total_failures*100.0:.1f}%)")
    print(f"  4. Complete Miss / Other         : {other:<3} ({other/total_failures*100.0:.1f}%)")
    print(f"==================================================")

    # Output detailed report markdown
    report = []
    report.append("# AURA Memory Failure Mode Analysis Report")
    report.append(f"\n- **Total Failures Analyzed**: {total_failures} out of 1000 cases")
    report.append("\n## Failure Mode Breakdown")
    report.append(f"\n| Failure Mode | Count | Percentage | Description |")
    report.append(f"|---|---|---|---|")
    report.append(f"| **Partial Recall (Omission)** | {omissions} | {omissions/total_failures*100.0:.1f}% | Model recalled some facts (e.g. user name) but omitted others (e.g. location/preference) |")
    report.append(f"| **Identity Confusion** | {identity_confusion} | {identity_confusion/total_failures*100.0:.1f}% | Model answered with its own name ('AURA') instead of the user's name when asked 'my name' |")
    report.append(f"| **Disclaimer Refusal** | {disclaimers} | {disclaimers/total_failures*100.0:.1f}% | Model defaulted to its pre-trained safety guardrail ('I don't have access to personal details') |")
    report.append(f"| **Complete Miss / Other** | {other} | {other/total_failures*100.0:.1f}% | Model completely failed to output expected keywords due to grammatical or formatting errors |")

    report.append("\n## Sample Failure Traces by Category")
    
    # Trace examples
    for cat_name in [
        "Partial Recall (Model retrieved some facts but omitted others, e.g. name but not preference)",
        "Identity/Pronoun Confusion (Model gave its own name/AURA instead of user name)",
        "Disclaimer Refusal (Model defaulted to 'I don't have access' standard safety phrase)",
        "Complete Miss / Alternative Phrasing (Model failed to output any expected keywords)"
    ]:
        report.append(f"\n### {cat_name.split(' (')[0]}")
        samples = [s for s in detailed_examples if s["error_type"] == cat_name][:3]
        for s in samples:
            report.append(f"\n- **Case #{s['id']}** ({s['category_name']})")
            report.append(f"  - *Query*: \"{s['query']}\"")
            report.append(f"  - *Expected*: `{s['expected']}`")
            report.append(f"  - *Got*: \"{s['got'].strip()}\"")

    with open("/home/pratay-karali/launch-AURA/Mitacs/failure_analysis_report.md", "w") as f:
        f.write("\n".join(report))
        
    print("Saved failure mode analysis report to /home/pratay-karali/launch-AURA/Mitacs/failure_analysis_report.md")

if __name__ == "__main__":
    analyze_failures()
