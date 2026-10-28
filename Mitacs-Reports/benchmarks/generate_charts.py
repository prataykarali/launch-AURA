import json
import os
import sys

def main():
    stats_path = "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_stats.json"
    if not os.path.exists(stats_path):
        print(f"Error: Stats file not found at {stats_path}. Please run the memory evaluation first.")
        sys.exit(1)

    with open(stats_path, "r") as f:
        stats = json.load(f)

    print("Generating performance charts and dashboard...")

    # Extract categories and difficulties
    categories = stats.get("categories", {})
    
    # Calculate difficulty stats manually since they aren't grouped in the JSON's categories
    difficulty_raw = {}
    for case in stats.get("cases", []):
        diff = case.get("difficulty", "unknown")
        passed = 1 if case.get("passed", False) else 0
        if diff not in difficulty_raw:
            difficulty_raw[diff] = {"passed": 0, "total": 0}
        difficulty_raw[diff]["passed"] += passed
        difficulty_raw[diff]["total"] += 1

    difficulties = {}
    for diff, val in difficulty_raw.items():
        difficulties[diff] = {
            "passed": val["passed"],
            "total": val["total"],
            "accuracy": (val["passed"] / val["total"]) * 100.0 if val["total"] > 0 else 0.0
        }

    # Generate category chart SVG — auto-assign colors from a palette
    palette = ["#4f46e5", "#06b6d4", "#10b981", "#f59e0b", "#ec4899",
               "#8b5cf6", "#14b8a6", "#f97316", "#64748b", "#ef4444"]
    cat_colors = {}
    for i, k in enumerate(categories.keys()):
        label = k.replace("_", " ").title()
        cat_colors[label] = palette[i % len(palette)]

    cat_svg = make_bar_chart(
        title="Accuracy by Evaluation Category",
        data={k.replace("_", " ").title(): v["accuracy"] for k, v in categories.items()},
        colors=cat_colors,
        y_max=100
    )
    
    # Generate difficulty chart SVG
    diff_order = ["simple", "medium", "hard", "very_hard", "extreme"]
    sorted_diffs = {}
    for d in diff_order:
        if d in difficulties:
            sorted_diffs[d.replace("_", " ").title()] = difficulties[d]["accuracy"]
            
    diff_svg = make_bar_chart(
        title="Accuracy by Query Difficulty",
        data=sorted_diffs,
        colors={
            "Simple": "#10b981",
            "Medium": "#3b82f6",
            "Hard": "#f59e0b",
            "Very Hard": "#ef4444",
            "Extreme": "#dc2626"
        },
        y_max=100
    )

    # Save SVGs
    with open("/home/pratay-karali/launch-AURA/Mitacs/category_accuracy.svg", "w") as f:
        f.write(cat_svg)
    with open("/home/pratay-karali/launch-AURA/Mitacs/difficulty_accuracy.svg", "w") as f:
        f.write(diff_svg)

    # Generate HTML Dashboard
    html_dashboard = make_html_dashboard(stats, difficulties, categories)
    with open("/home/pratay-karali/launch-AURA/Mitacs/dashboard.html", "w") as f:
        f.write(html_dashboard)

    print("Successfully generated all reports in /home/pratay-karali/launch-AURA/Mitacs/")

def make_bar_chart(title, data, colors, y_max=100):
    width = 650
    height = 380
    padding_left = 80
    padding_right = 30
    padding_top = 60
    padding_bottom = 60

    chart_width = width - padding_left - padding_right
    chart_height = height - padding_top - padding_bottom

    keys = list(data.keys())
    values = list(data.values())
    num_bars = len(keys)
    bar_width = (chart_width / num_bars) * 0.6
    bar_spacing = (chart_width / num_bars) * 0.4

    svg = []
    svg.append(f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg" style="background:#0f172a; border-radius:12px; font-family:\'Outfit\', \'Inter\', sans-serif;">')
    
    # Shadows and Gradients
    svg.append("""
    <defs>
        <filter id="drop-shadow" x="-10%" y="-10%" width="120%" height="120%">
            <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#000" flood-opacity="0.4"/>
        </filter>
        <linearGradient id="grid-grad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#1e293b" stop-opacity="0.8"/>
            <stop offset="100%" stop-color="#0f172a" stop-opacity="1"/>
        </linearGradient>
    </defs>
    """)

    # Styles and Animations
    svg.append("""
    <style>
        .title { fill: #f8fafc; font-size: 18px; font-weight: 700; }
        .axis-label { fill: #94a3b8; font-size: 12px; }
        .tick-label { fill: #64748b; font-size: 11px; }
        .grid-line { stroke: #334155; stroke-dasharray: 4,4; stroke-width: 0.8; }
        .bar-label { fill: #f8fafc; font-size: 12px; font-weight: 600; text-anchor: middle; opacity: 0; animation: fadeIn 0.5s ease forwards 0.8s; }
        .bar { filter: url(#drop-shadow); transition: all 0.3s ease; transform-origin: bottom; animation: growUp 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards; }
        .bar:hover { filter: brightness(1.2) url(#drop-shadow); cursor: pointer; }
        @keyframes growUp {
            from { transform: scaleY(0); }
            to { transform: scaleY(1); }
        }
        @keyframes fadeIn {
            to { opacity: 1; }
        }
    </style>
    """)

    # Title
    svg.append(f'<text x="{width / 2}" y="35" text-anchor="middle" class="title">{title}</text>')

    # Gridlines & Y-axis ticks
    for i in range(6):
        pct = (i / 5) * y_max
        y = padding_top + chart_height - (i / 5) * chart_height
        svg.append(f'<line x1="{padding_left}" y1="{y}" x2="{width - padding_right}" y2="{y}" class="grid-line"/>')
        svg.append(f'<text x="{padding_left - 15}" y="{y + 4}" text-anchor="end" class="tick-label">{pct:.0f}%</text>')

    # Draw Bars
    for idx, (k, val) in enumerate(zip(keys, values)):
        bar_height = (val / y_max) * chart_height
        x = padding_left + (idx * (bar_width + bar_spacing)) + (bar_spacing / 2)
        y = padding_top + chart_height - bar_height
        color = colors.get(k, "#3b82f6")

        # Create gradient for individual bar
        grad_id = f"bar-grad-{idx}"
        svg.append(f"""
        <linearGradient id="{grad_id}" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="{color}"/>
            <stop offset="100%" stop-color="{color}" stop-opacity="0.4"/>
        </linearGradient>
        """)

        # Add bar with transform-origin set for grow animation
        svg.append(f'<rect x="{x}" y="{y}" width="{bar_width}" height="{bar_height}" rx="6" ry="6" fill="url(#{grad_id})" class="bar" style="transform-origin: {x + bar_width/2}px {padding_top + chart_height}px;"/>')
        
        # Accuracy Text above bar
        svg.append(f'<text x="{x + bar_width / 2}" y="{y - 8}" class="bar-label">{val:.1f}%</text>')

        # X-axis label
        svg.append(f'<text x="{x + bar_width / 2}" y="{padding_top + chart_height + 25}" text-anchor="middle" class="axis-label">{k}</text>')

    # Axes
    svg.append(f'<line x1="{padding_left}" y1="{padding_top}" x2="{padding_left}" y2="{padding_top + chart_height}" stroke="#334155" stroke-width="1.5"/>')
    svg.append(f'<line x1="{padding_left}" y1="{padding_top + chart_height}" x2="{width - padding_right}" y2="{padding_top + chart_height}" stroke="#334155" stroke-width="1.5"/>')

    svg.append("</svg>")
    return "\n".join(svg)

def make_html_dashboard(stats, difficulties, categories):
    date = stats.get("date", "Unknown Date")
    total = stats.get("total_cases", 0)
    passed = stats.get("passed", 0)
    failed = stats.get("failed", 0)
    accuracy = stats.get("accuracy", 0.0)
    duration = stats.get("suite_run_time_secs", 0.0)

    # Make table rows for individual test cases
    table_rows = []
    # Show first 10 failures or interesting cases
    failures = [c for c in stats.get("cases", []) if not c.get("passed", False)]
    passes = [c for c in stats.get("cases", []) if c.get("passed", False)]
    
    cases_to_show = failures[:15] + passes[:10]  # Show up to 15 failures and 10 passes for reference
    for case in cases_to_show:
        status_badge = '<span class="badge badge-pass">PASSED</span>' if case["passed"] else '<span class="badge badge-fail">FAILED</span>'
        expected = ", ".join(case["expected"])
        got_escaped = case["got"].replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")
        table_rows.append(f"""
        <tr>
            <td>#{case["id"]}</td>
            <td><span class="category-tag">{case["category"].replace("_", " ").title()}</span></td>
            <td><span class="difficulty-tag diff-{case["difficulty"]}">{case["difficulty"].upper()}</span></td>
            <td>{case["query"]}</td>
            <td><code>{expected}</code></td>
            <td class="got-cell">{got_escaped}</td>
            <td>{status_badge}</td>
            <td>{case["duration_ms"]}ms</td>
        </tr>
        """)

    table_body = "\n".join(table_rows)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AURA Memory Recall Evaluation Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700;800&family=JetBrains+Mono&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-color: #020617;
            --card-bg: rgba(30, 41, 59, 0.4);
            --card-border: rgba(255, 255, 255, 0.05);
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent-primary: #6366f1;
            --accent-success: #10b981;
            --accent-warning: #f59e0b;
            --accent-danger: #ef4444;
        }}
        
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        
        body {{
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: 'Outfit', sans-serif;
            padding: 2.5rem 1.5rem;
            min-height: 100vh;
        }}
        
        .container {{
            max-width: 1400px;
            margin: 0 auto;
        }}
        
        header {{
            margin-bottom: 2.5rem;
            text-align: center;
        }}
        
        header h1 {{
            font-size: 2.5rem;
            font-weight: 800;
            background: linear-gradient(135deg, #a5b4fc, #6366f1, #38bdf8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 0.5rem;
        }}
        
        header p {{
            color: var(--text-muted);
            font-size: 1.1rem;
        }}
        
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2.5rem;
        }}
        
        .stat-card {{
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 1.5rem;
            backdrop-filter: blur(12px);
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            position: relative;
            overflow: hidden;
        }}
        
        .stat-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--accent-primary);
        }}
        
        .stat-card.passed-card::before {{ background: var(--accent-success); }}
        .stat-card.failed-card::before {{ background: var(--accent-danger); }}
        .stat-card.accuracy-card::before {{ background: linear-gradient(to bottom, #818cf8, #c084fc); }}
        
        .stat-label {{
            color: var(--text-muted);
            font-size: 0.9rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.5rem;
        }}
        
        .stat-value {{
            font-size: 2.2rem;
            font-weight: 700;
            line-height: 1.2;
        }}
        
        .stat-meta {{
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-top: 0.5rem;
        }}
        
        .charts-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 2rem;
            margin-bottom: 2.5rem;
        }}
        
        @media (max-width: 768px) {{
            .charts-grid {{
                grid-template-columns: 1fr;
            }}
        }}
        
        .chart-card {{
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 20px;
            padding: 1.5rem;
            backdrop-filter: blur(12px);
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
        }}
        
        .chart-card h2 {{
            font-size: 1.25rem;
            margin-bottom: 1rem;
            align-self: flex-start;
            color: var(--text-main);
            font-weight: 600;
        }}
        
        .chart-container {{
            width: 100%;
            display: flex;
            justify-content: center;
        }}
        
        .chart-container svg {{
            width: 100%;
            height: auto;
            max-width: 650px;
        }}
        
        .details-section {{
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 20px;
            padding: 2rem;
            backdrop-filter: blur(12px);
        }}
        
        .details-section h2 {{
            font-size: 1.5rem;
            margin-bottom: 1.2rem;
            font-weight: 700;
        }}
        
        .table-container {{
            width: 100%;
            overflow-x: auto;
        }}
        
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.95rem;
            text-align: left;
        }}
        
        th {{
            border-bottom: 2px solid var(--card-border);
            padding: 1rem;
            color: var(--text-muted);
            font-weight: 600;
        }}
        
        td {{
            padding: 1rem;
            border-bottom: 1px solid var(--card-border);
            vertical-align: top;
        }}
        
        tr:hover td {{
            background: rgba(255, 255, 255, 0.02);
        }}
        
        .badge {{
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.05em;
        }}
        
        .badge-pass {{
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-success);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }}
        
        .badge-fail {{
            background: rgba(239, 68, 68, 0.15);
            color: var(--accent-danger);
            border: 1px solid rgba(239, 68, 68, 0.3);
        }}
        
        .category-tag {{
            background: rgba(99, 102, 241, 0.15);
            color: #a5b4fc;
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-size: 0.8rem;
        }}
        
        .difficulty-tag {{
            font-size: 0.8rem;
            font-weight: 600;
        }}
        
        .diff-simple {{ color: var(--accent-success); }}
        .diff-medium {{ color: #3b82f6; }}
        .diff-hard {{ color: var(--accent-warning); }}
        .diff-very_hard {{ color: var(--accent-danger); }}
        
        .got-cell {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.85rem;
            color: #cbd5e1;
            max-width: 350px;
            word-break: break-word;
        }}
        
        code {{
            font-family: 'JetBrains Mono', monospace;
            background: rgba(0, 0, 0, 0.3);
            padding: 0.15rem 0.3rem;
            border-radius: 4px;
            color: #e2e8f0;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>AURA Personal AI Memory Evaluation</h1>
            <p>1000-Case Personal AI Assistant Benchmark &bull; XML Profile Isolation + Pre-filling + Jaro-Winkler &bull; {date}</p>
        </header>
        
        <div class="summary-grid">
            <div class="stat-card">
                <div class="stat-label">Total Test Cases</div>
                <div class="stat-value">{total}</div>
                <div class="stat-meta">10 categories of 100 cases</div>
            </div>
            <div class="stat-card passed-card">
                <div class="stat-label">Passed Cases</div>
                <div class="stat-value" style="color: var(--accent-success);">{passed}</div>
                <div class="stat-meta">Matched all expected keywords</div>
            </div>
            <div class="stat-card failed-card">
                <div class="stat-label">Failed Cases</div>
                <div class="stat-value" style="color: var(--accent-danger);">{failed}</div>
                <div class="stat-meta">Did not recall target elements</div>
            </div>
            <div class="stat-card accuracy-card">
                <div class="stat-label">Memory Accuracy</div>
                <div class="stat-value">{accuracy:.2f}%</div>
                <div class="stat-meta">Target: &gt;80% accuracy</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Suite Duration</div>
                <div class="stat-value">{duration:.1f}s</div>
                <div class="stat-meta">Avg: {(duration * 1000 / total):.1f}ms per case</div>
            </div>
        </div>
        
        <div class="charts-grid">
            <div class="chart-card">
                <h2>Recall Accuracy by RAG Category</h2>
                <div class="chart-container">
                    <img src="category_accuracy.svg" alt="Category Accuracy Chart" style="width: 100%; height: auto;">
                </div>
            </div>
            <div class="chart-card">
                <h2>Recall Accuracy by Difficulty Level</h2>
                <div class="chart-container">
                    <img src="difficulty_accuracy.svg" alt="Difficulty Accuracy Chart" style="width: 100%; height: auto;">
                </div>
            </div>
        </div>
        
        <div class="details-section">
            <h2>Detailed Evaluation Traces (Subset of Failures & Passes)</h2>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 5%">ID</th>
                            <th style="width: 15%">Category</th>
                            <th style="width: 10%">Difficulty</th>
                            <th style="width: 25%">Verification Query</th>
                            <th style="width: 15%">Expected Keywords</th>
                            <th style="width: 20%">AURA Response</th>
                            <th style="width: 5%">Status</th>
                            <th style="width: 5%">Latency</th>
                        </tr>
                    </thead>
                    <tbody>
                        {table_body}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</body>
</html>
"""
    return html

if __name__ == "__main__":
    main()
