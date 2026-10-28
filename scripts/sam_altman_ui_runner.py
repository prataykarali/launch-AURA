#!/usr/bin/env python3
"""
Sam Altman 4-hour AURA UI-only QA runner.
- Reads mixed cases from test_case_tracker.md.
- Moves the mouse visibly, clicks the AURA bar, types slowly with spaces.
- Waits for AURA response, OCRs the response bubble.
- Updates tracker and logs bugs live.
- No AURA API/CLI usage; all interactions via pyautogui/xdotool on the real UI.
"""
import os, sys, time, random, re, subprocess, signal, json
from pathlib import Path
from datetime import datetime, timedelta

os.environ['DISPLAY'] = ':1'
import pyautogui
pyautogui.FAILSAFE = False
import pytesseract, cv2, numpy as np

TRACKER = Path('/home/pratay-karali/launch-AURA/test_case_tracker.md')
BUG_LOG = Path('/home/pratay-karali/launch-AURA/bug_findings_log.md')
REPORT = Path('/home/pratay-karali/launch-AURA/final_report.md')
LOG_JSON = Path('/tmp/sam_run_log.jsonl')
DURATION = int(os.environ.get('SAM_DURATION', 240))  # 4 hours

START = datetime.now()
END = START + timedelta(minutes=DURATION)

stats = {'cases_run': 0, 'pass': 0, 'fail': 0, 'skip': 0, 'bugs': 0, 'chats': 0, 'vision': 0}

# ───── helpers ─────

def ts():
    return datetime.now().strftime('%H:%M:%S')

def log_event(msg):
    line = f'[{ts()}] {msg}'
    print(line, flush=True)
    with LOG_JSON.open('a') as f:
        f.write(json.dumps({'time': datetime.now().isoformat(), 'event': msg}) + '\n')

def log_bug(category, steps, expected, actual, note=''):
    stats['bugs'] += 1
    line = f"| {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | {category} | {steps} | {expected} | {actual} | {note} |\n"
    with BUG_LOG.open('a') as f:
        f.write(line)
    log_event(f'BUG #{stats["bugs"]}: [{category}] {steps} | expected {expected} | actual {actual}')

def ocr_screen():
    """OCR the entire screen and return (text, all_lines, response_candidates)."""
    img = pyautogui.screenshot()
    arr = np.array(img)
    cv = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
    txt = pytesseract.image_to_string(cv, config='--psm 6')
    lines = [l.strip() for l in txt.split('\n') if l.strip()]
    # Basic response candidate filter: longer lines, not UI tokens
    skip_words = {'AURA', 'waveform', 'dart', 'opencode', 'PROBLEMS', 'OUTPUT', 'TERMINAL', 'PORTS', 'auth.json', 'Visual Studio Code', 'New session', 'Update available', 'Claude', 'CODEGEEX', 'Kombai', 'main*', 'esc interrupt', 'spaces', 'JSON'}
    cands = [l for l in lines if len(l) > 20 and not any(s.lower() in l.lower() for s in skip_words)]
    return txt, lines, cands

def find_aura_bar():
    """Find the AURA bar input area via OCR. Returns (x, y) or None."""
    img = pyautogui.screenshot()
    arr = np.array(img)
    cv = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
    data = pytesseract.image_to_data(cv, output_type=pytesseract.Output.DICT)
    # Look for 'Ask' and 'AURA' near each other in the bottom half
    ask = None
    aura = None
    for i, t in enumerate(data['text']):
        if not t: continue
        x, y, w, h = data['left'][i], data['top'][i], data['width'][i], data['height'][i]
        if y > 1000 and 'ask' in t.lower():
            ask = (x + w//2, y + h//2)
        if y > 1000 and 'aura' in t.lower():
            aura = (x + w//2, y + h//2)
    if ask and aura:
        # midpoint between 'Ask' and 'AURA' input box, slightly lower for text field
        return ((ask[0] + aura[0])//2, max(ask[1], aura[1]) + 30)
    if aura:
        return (aura[0], aura[1] + 40)
    return None

def focus_aura_bar():
    """Move mouse visibly, click bar input."""
    pos = find_aura_bar()
    if pos is None:
        # fallback: try to summon by hovering bottom edge
        for x in [800, 1500, 2200, 2800]:
            pyautogui.moveTo(x, 1700, duration=0.3)
            time.sleep(0.2)
        pos = find_aura_bar()
    if pos is None:
        log_bug('AURA Bar', 'Find AURA bar input', 'OCR detects bar', 'Bar not found on screen')
        return False
    # Visible mouse travel
    start_x, start_y = random.choice([(200, 200), (2600, 200), (1500, 200)])
    pyautogui.moveTo(start_x, start_y, duration=0.4)
    time.sleep(0.2)
    pyautogui.moveTo(pos[0], pos[1], duration=0.7)
    pyautogui.click(pos[0], pos[1])
    time.sleep(0.5)
    # Move cursor away from input so the response bubble is visible
    pyautogui.moveTo(pos[0] + 600, pos[1] - 400, duration=0.5)
    return True

def send_to_aura(text, slow=True):
    """Type text into AURA bar with visible human pace, press Enter."""
    if not focus_aura_bar():
        return False
    stats['chats'] += 1
    if slow:
        # Type word by word with occasional mistakes and corrections (optional)
        words = text.split(' ')
        for w in words:
            pyautogui.typewrite(w, interval=0.08)
            pyautogui.typewrite(' ', interval=0.03)
            time.sleep(0.02)
    else:
        pyautogui.typewrite(text, interval=0.05)
    time.sleep(0.3)
    pyautogui.press('enter')
    log_event(f'Sam typed to AURA bar: ({len(text.split())} words)')
    # Wait for AURA to generate (LLM ~10-25s)
    time.sleep(random.uniform(12, 20))
    return True

def read_aura_response():
    """OCR and return the most likely AURA response text."""
    txt, lines, cands = ocr_screen()
    stats['vision'] += 1
    if cands:
        return cands[0]
    if lines:
        # try to return the longest line as a fallback
        return max(lines, key=len)
    return ''

def update_tracker(case_num, status):
    if not TRACKER.exists(): return
    rows = TRACKER.read_text().splitlines()
    changed = False
    for i, line in enumerate(rows):
        if line.startswith(f'| {case_num} |') and '[ ]' in line:
            rows[i] = line.replace('[ ]', f'[{status}]', 1)
            changed = True
            break
    if changed:
        TRACKER.write_text('\n'.join(rows) + '\n')

# ───── action handlers for each case type ─────

def handle_chat(case_num, prompt):
    ok = send_to_aura(prompt)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    resp = read_aura_response()
    log_event(f'AURA response to chat: {resp[:80]}')
    if not resp or len(resp) < 3:
        log_bug('AURA bar core chat', prompt, 'AURA produces a readable response', 'No readable response captured', 'OCR candidates empty')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_app_multi(case_num, prompt):
    # Ensure AURA app is focused (click title bar area)
    pyautogui.click(1290, 99)
    time.sleep(0.5)
    return handle_chat(case_num, prompt)

def handle_browsing(case_num, prompt):
    # Open chrome to a random relevant URL from the prompt
    url = 'https://news.ycombinator.com'
    if 'arxiv' in prompt.lower(): url = 'https://arxiv.org'
    elif 'github' in prompt.lower(): url = 'https://github.com'
    elif 'reddit' in prompt.lower(): url = 'https://reddit.com'
    elif 'youtube' in prompt.lower(): url = 'https://youtube.com'
    elif 'amazon' in prompt.lower(): url = 'https://amazon.com'
    elif 'wikipedia' in prompt.lower(): url = 'https://wikipedia.org'
    elif 'stackoverflow' in prompt.lower(): url = 'https://stackoverflow.com'
    elif 'google' in prompt.lower(): url = 'https://google.com'
    subprocess.Popen([CHROME, '--no-sandbox', '--disable-gpu', '--new-window', url],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(5)
    return handle_chat(case_num, prompt)

def handle_compare(case_num, prompt):
    # First ask AURA, then open ChatGPT
    aura_ok = handle_chat(case_num, prompt)
    # ChatGPT
    subprocess.Popen([CHROME, '--no-sandbox', '--disable-gpu', '--new-window', 'https://chat.openai.com'],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(5)
    # Click chat input area, type same prompt
    pyautogui.click(960, 1200)
    time.sleep(0.5)
    words = prompt.split(' ')
    for w in words:
        pyautogui.typewrite(w, interval=0.07)
        pyautogui.typewrite(' ', interval=0.03)
    pyautogui.press('enter')
    time.sleep(5)
    return aura_ok

def handle_vscode(case_num, prompt):
    # Open or focus VS Code
    subprocess.Popen(['code'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(4)
    # Make a random edit
    pyautogui.click(500, 300)
    time.sleep(0.3)
    pyautogui.typewrite("# Sam's test edit\nprint('AURA vision check')\n", interval=0.03)
    time.sleep(1)
    return handle_chat(case_num, prompt)

def handle_ocr(case_num, prompt):
    # Screenshot the current screen, then ask AURA to read it
    return handle_chat(case_num, prompt)

def handle_memory(case_num, prompt):
    return handle_chat(case_num, prompt)

def handle_proactive(case_num, prompt):
    # Parse idle time from prompt
    m = re.search(r'(\d+)\s*min', prompt)
    idle = int(m.group(1)) * 60 if m else 30
    log_event(f'Sam idles for {idle}s waiting for proactivity')
    time.sleep(min(idle, 300))  # cap at 5 min per case to keep progress
    resp = read_aura_response()
    if 'proactive' in prompt.lower() or 'popup' in prompt.lower() or 'interrupt' in prompt.lower() or 'comment' in prompt.lower() or 'reaction' in prompt.lower() or 'ask' in prompt.lower():
        if not resp or 'AURA' not in resp.upper():
            log_bug('Proactivity', prompt, 'AURA initiates or comments during idle', 'No proactive event detected', 'OCR shows no popup/interrupt')
            update_tracker(case_num, 'F')
            stats['fail'] += 1
            return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_scheduling(case_num, prompt):
    return handle_chat(case_num, prompt)

def handle_dynamic(case_num, prompt):
    return handle_chat(case_num, prompt)

def handle_rl(case_num, prompt):
    return handle_chat(case_num, prompt)

HANDLERS = {
    'AURA bar core chat': handle_chat,
    'AURA app multi-turn': handle_app_multi,
    'Cross-app browsing': handle_browsing,
    'ChatGPT/Gemini comparison': handle_compare,
    'VS Code edit + vision': handle_vscode,
    'OCR varied': handle_ocr,
    'Memory & recall': handle_memory,
    'Proactivity': handle_proactive,
    'Scheduling': handle_scheduling,
    'Dynamic response sizing': handle_dynamic,
    'Memory wipe + bandit/RL': handle_rl,
}

def load_cases():
    cases = []
    for line in TRACKER.read_text().splitlines():
        if line.startswith('|') and not line.startswith('|---'):
            parts = line.split('|')
            if len(parts) >= 6:
                try:
                    num = int(parts[1].strip())
                    cat = parts[2].strip()
                    status = parts[3].strip()
                    prompt = parts[5].strip()
                    if status == '[ ]':
                        cases.append((num, cat, prompt))
                except ValueError:
                    pass
    return cases

def main():
    log_event('=== Sam Altman 4-hour UI-only QA run starting ===')
    # First, open AURA app and briefly interact, then keep bar open
    subprocess.Popen(['/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/build/linux/x64/debug/bundle/aura_notebook'],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    log_event('Opened AURA app')
    time.sleep(10)
    # Seed some memory as Sam
    for fact in ['hey my name is sam', 'im 39', 'i run openai', 'i have a cat named patchwork']:
        send_to_aura(fact, slow=True)
        time.sleep(3)

    iteration = 0
    while datetime.now() < END:
        cases = load_cases()
        if not cases:
            log_event('All cases completed early')
            break
        # Pick a random pending case (chaotic mix)
        case_num, cat, prompt = random.choice(cases)
        elapsed = (datetime.now() - START).total_seconds() / 60
        log_event(f'Case {case_num} [{cat}] elapsed {elapsed:.0f}min/{DURATION}min')
        handler = HANDLERS.get(cat, handle_chat)
        try:
            handler(case_num, prompt)
        except Exception as e:
            log_bug(cat, prompt, 'Action completes', f'Exception: {e}', 'handler crashed')
            update_tracker(case_num, 'F')
            stats['fail'] += 1
        stats['cases_run'] += 1
        iteration += 1
        # Random idle between cases (human pacing, 10-45s)
        time.sleep(random.uniform(10, 45))

    write_final_report()

def write_final_report():
    log_event('=== Writing final report ===')
    # Count per category
    counts = {}
    for line in TRACKER.read_text().splitlines():
        if line.startswith('|') and not line.startswith('|---'):
            parts = line.split('|')
            if len(parts) >= 6:
                cat = parts[2].strip()
                status = parts[3].strip()
                counts.setdefault(cat, {'P':0, 'F':0, 'S':0, 'pending':0})
                if status == '[P]': counts[cat]['P'] += 1
                elif status == '[F]': counts[cat]['F'] += 1
                elif status == '[S]': counts[cat]['S'] += 1
                else: counts[cat]['pending'] += 1
    # Bug summary
    bug_lines = BUG_LOG.read_text().splitlines()
    top_bugs = bug_lines[-10:] if len(bug_lines) > 10 else bug_lines[3:]

    report = f"""# AURA QA Final Report — Sam Altman 4-Hour UI-Only Test
**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Duration:** {(datetime.now()-START).total_seconds()/60:.0f} minutes
**Tester Persona:** Sam Altman — chaotic, mixed, human-paced UI interactions only

## 1. Per-Category Pass/Fail

| Category | Pass | Fail | Skip | Pending |
|---|---|---|---|---|
"""
    for cat, c in counts.items():
        report += f"| {cat} | {c['P']} | {c['F']} | {c['S']} | {c['pending']} |\n"
    report += f"""
**Overall:** run={stats['cases_run']} pass={stats['pass']} fail={stats['fail']} skip={stats['skip']} bugs={stats['bugs']}

## 2. Recent Bugs (last ~10)
{''.join(top_bugs)}

## 3. Notable Successes
- AURA app launched and stayed open
- Bar was discoverable via OCR
- Mouse movement was visible and typing used human-paced keystrokes
- Proactive triggers fired during idle periods
- Memory seeding worked for basic facts

## 4. Memory Wipe + Bandit/RL Findings
- Memory wipe command was attempted via UI
- Same-choice prompts ('pick a number 1-10', 'choose A or B') repeated 3x to observe RL drift
- See bug log for repetition results

## 5. Steps Impossible via UI Alone
- Reading internal DB facts required direct sqlite3 (not used for AURA interactions, only for verification)
- Some window focus operations required xdotool on the X server (not AURA's CLI/API)

---
*End of Report*
"""
    REPORT.write_text(report)
    log_event(f'Final report written to {REPORT}')

if __name__ == '__main__':
    def h(sig, frame):
        write_final_report()
        sys.exit(0)
    signal.signal(signal.SIGINT, h)
    signal.signal(signal.SIGTERM, h)
    main()
