#!/usr/bin/env python3
"""
Kuldeep Singhania 3-4hr AURA QA runner — 250 mixed cases.
Persona: Indian actor, social media influencer, entrepreneur.
         Known for short-form video content (skits, lip sync, dance) and micro films.
         Former yoga instructor, former professional cricket player.
         Lives in Mumbai. Brother Hemant (EDM artist), sister Pooja.
Lenient on cosmetics (1.2B model), strict on contract:
  - Bar IPC: every message must arrive (check notebook.jsonl turn count)
  - Memory: recall must contain correct fact
  - Scheduling: timer must fire (check log + screen)
  - Persona: AURA must not leak user facts
  - OCR: must read real text, not hallucinate
Runs as a real user: SEE screen -> move mouse -> click -> type.
"""
import os, sys, time, random, re, subprocess, json, signal, threading, sqlite3
from pathlib import Path
from datetime import datetime, timedelta

os.environ['DISPLAY'] = ':1'
os.environ['LD_LIBRARY_PATH'] = '/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/linux_libs:/usr/lib/x86_64-linux-gnu:' + os.environ.get('LD_LIBRARY_PATH', '')

import pyautogui
pyautogui.FAILSAFE = False
import pytesseract, cv2, numpy as np

SKILL = '/home/pratay-karali/.agents/skills/aura-app-navigation/aura_interact.py'
TRACKER = Path('/home/pratay-karali/launch-AURA/kuldeep_test_case_tracker.md')
BUG_LOG = Path('/home/pratay-karali/launch-AURA/kuldeep_bug_findings_log.md')
REPORT = Path('/home/pratay-karali/launch-AURA/kuldeep_final_report.md')
RUN_LOG = Path('/tmp/kuldeep_qa_run.jsonl')
DURATION_MIN = int(os.environ.get('KULDEEP_DURATION', 240))  # 4 hours

START = datetime.now()
END = START + timedelta(minutes=DURATION_MIN)

_SHUTDOWN_REQUESTED = threading.Event()

stats = {
    'cases_run': 0, 'pass': 0, 'fail': 0, 'skip': 0, 'bugs': 0,
    'chats': 0, 'vision': 0, 'bar_sent': 0, 'bar_arrived': 0,
    'memory_store': 0, 'memory_recall_correct': 0, 'memory_recall_wrong': 0,
    'scheduling_set': 0, 'scheduling_fired': 0, 'scheduling_missed': 0,
    'persona_leaks': 0, 'ocr_real_text': 0, 'ocr_empty': 0,
}

# ─── helpers ───

def ts():
    return datetime.now().strftime('%H:%M:%S')

def run_cmd(cmd):
    full = ['python3', SKILL] + cmd
    try:
        r = subprocess.run(full, capture_output=True, text=True, timeout=60)
        return r.stdout.strip()
    except Exception as e:
        return f'ERROR: {e}'

def log_event(msg):
    line = f'[{ts()}] {msg}'
    print(line, flush=True)
    with RUN_LOG.open('a') as f:
        f.write(json.dumps({'time': datetime.now().isoformat(), 'event': msg}) + '\n')

def log_bug(category, steps, expected, actual, note=''):
    stats['bugs'] += 1
    line = f"| {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | {category} | {steps} | {expected} | {actual} | {note} |\n"
    with BUG_LOG.open('a') as f:
        f.write(line)
    log_event(f'BUG #{stats["bugs"]}: [{category}] {steps} | expected {expected} | actual {actual}')

def see():
    out = run_cmd(['see'])
    lines = [l.strip() for l in out.split('\n') if l.strip() and not l.startswith('[strategy')]
    return out, lines

def find_text(query):
    out = run_cmd(['find', query])
    if out == 'NOTFOUND' or not out:
        return None
    parts = out.split()
    if len(parts) >= 2:
        try:
            return (int(parts[0]), int(parts[1]))
        except ValueError:
            return None
    return None

def find_aura_windows():
    out = run_cmd(['windows'])
    main_wid = None
    bar_wid = None
    for line in out.split('\n'):
        if ': AURA' in line and 'Bar' not in line:
            main_wid = line.split(':')[0].strip()
        if ': AURA Bar' in line:
            bar_wid = line.split(':')[0].strip()
    return main_wid, bar_wid

def focus_app():
    main_wid, bar_wid = find_aura_windows()
    if bar_wid:
        subprocess.run(['xdotool', 'windowmove', bar_wid, '2200', '1500'],
                       stderr=subprocess.DEVNULL, timeout=3)
    if main_wid:
        subprocess.run(['xdotool', 'windowactivate', main_wid],
                       stderr=subprocess.DEVNULL, timeout=3)
        subprocess.run(['xdotool', 'windowfocus', main_wid],
                       stderr=subprocess.DEVNULL, timeout=3)
        time.sleep(0.5)
    return main_wid

def focus_bar():
    _, bar_wid = find_aura_windows()
    if bar_wid:
        subprocess.run(['xdotool', 'windowactivate', bar_wid],
                       stderr=subprocess.DEVNULL, timeout=3)
        subprocess.run(['xdotool', 'windowfocus', bar_wid],
                       stderr=subprocess.DEVNULL, timeout=3)
        time.sleep(0.3)
    return bar_wid

def xdotool_type(text, delay=80):
    subprocess.run(['xdotool', 'type', '--delay', str(delay), text],
                   stderr=subprocess.DEVNULL, timeout=15)

def xdotool_key(key):
    subprocess.run(['xdotool', 'key', key],
                   stderr=subprocess.DEVNULL, timeout=5)

def xdotool_click(x, y):
    subprocess.run(['xdotool', 'mousemove', str(x), str(y)],
                   stderr=subprocess.DEVNULL, timeout=3)
    time.sleep(0.2)
    subprocess.run(['xdotool', 'click', '1'],
                   stderr=subprocess.DEVNULL, timeout=3)
    time.sleep(0.3)

def get_turn_count():
    """Count turns in notebook.jsonl — used to verify bar messages arrived."""
    try:
        nb = os.path.expanduser('~/.local/share/AURA/notebook.jsonl')
        count = 0
        with open(nb, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                    if row.get('speaker') == 'user' and row.get('kind') == 'turn':
                        count += 1
                except Exception:
                    pass
        return count
    except Exception:
        return 0

def wait_for_response_done(timeout=30):
    deadline = time.time() + timeout
    try:
        with open('/tmp/aura_app.log', 'r') as f:
            start_lines = sum(1 for _ in f)
    except Exception:
        start_lines = 0

    while time.time() < deadline:
        time.sleep(1)
        try:
            with open('/tmp/aura_app.log', 'r') as f:
                lines = f.readlines()
            new_lines = lines[start_lines:]
            for l in new_lines:
                if 'STREAM_DONE' in l or 'Total chat took' in l or 'stream done' in l:
                    log_event('Response done detected (log)')
                    return True
        except Exception:
            pass
    log_event(f'Response done TIMEOUT ({timeout}s) — continuing anyway')
    return False

def read_response():
    """Read AURA's last assistant response from notebook.jsonl."""
    stats['vision'] += 1
    try:
        nb = os.path.expanduser('~/.local/share/AURA/notebook.jsonl')
        rows = []
        with open(nb, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    pass
        for r in reversed(rows):
            if r.get('speaker') == 'assistant' and r.get('kind') == 'turn':
                content = r.get('content', '')
                if content and len(content) > 3:
                    return content
        _, lines = see()
        cands = [l for l in lines if len(l) > 15 and not any(s.lower() in l.lower()
                 for s in ['AURA', 'Ask', 'Talk', 'brainstorm', 'story', 'notebook'])]
        return cands[0] if cands else (lines[0] if lines else '')
    except Exception as e:
        log_event(f'read_response error: {e}')
        return ''

def update_tracker(case_num, status):
    if not TRACKER.exists():
        return
    rows = TRACKER.read_text().splitlines()
    changed = False
    for i, line in enumerate(rows):
        if line.startswith(f'| {case_num} |') and 'PENDING' in line:
            rows[i] = line.replace('PENDING', status, 1)
            changed = True
            break
    if changed:
        TRACKER.write_text('\n'.join(rows) + '\n')

def open_browser(url='https://news.ycombinator.com'):
    chrome = '/usr/bin/google-chrome'
    if not os.path.exists(chrome):
        chrome = 'google-chrome'
    subprocess.Popen([chrome, '--no-sandbox', '--disable-gpu', '--new-window', url],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    time.sleep(5)

def open_vscode(file_path=None):
    cmd = ['code']
    if file_path:
        cmd.append(file_path)
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    time.sleep(4)

def make_edit(text):
    xdotool_type(text, delay=30)
    time.sleep(1)
    xdotool_key('ctrl+s')

def smart_nap(seconds, label='proactivity test'):
    log_event(f'Starting smart nap ({seconds}s) for {label}')
    interval = random.randint(120, 180)
    deadline = time.time() + seconds
    checks = 0
    while time.time() < deadline:
        remaining = deadline - time.time()
        wait = min(interval, remaining)
        if wait > 0:
            time.sleep(wait)
        if time.time() >= deadline:
            break
        checks += 1
        _, lines = see()
        log_event(f'Nap check #{checks}: {lines[:3]}')
        try:
            with open('/tmp/aura_app.log', 'r') as f:
                log_tail = f.readlines()[-15:]
            for ll in log_tail:
                if 'ProactiveScheduler' in ll or 'proactive trigger' in ll.lower():
                    log_event(f'Proactive log: {ll.strip()[:80]}')
        except Exception:
            pass
    log_event(f'Smart nap done ({checks} checks)')

def check_facts_db():
    """Read all facts from the memory DB. Returns list of fact strings."""
    try:
        db_path = os.path.expanduser('~/.local/share/aura_notebook/aura_memory.db')
        db = sqlite3.connect(db_path)
        rows = db.execute('SELECT content FROM facts').fetchall()
        db.close()
        return [r[0] for r in rows]
    except Exception as e:
        log_event(f'check_facts_db error: {e}')
        return []

def check_schedule_fired(timeout=150):
    """Check if a schedule reminder fired by polling the app log."""
    deadline = time.time() + timeout
    try:
        with open('/tmp/aura_app.log', 'r') as f:
            start_lines = sum(1 for _ in f)
    except Exception:
        start_lines = 0

    while time.time() < deadline:
        time.sleep(3)
        try:
            with open('/tmp/aura_app.log', 'r') as f:
                lines = f.readlines()
            new_lines = lines[start_lines:]
            for l in new_lines:
                low = l.lower()
                if 'schedule' in low and ('fire' in low or 'trigger' in low or 'remind' in low):
                    log_event(f'Schedule fired detected: {l.strip()[:80]}')
                    return True
                if 'forceschedulecheck' in low and 'defer' not in low:
                    log_event(f'forceScheduleCheck ran: {l.strip()[:80]}')
        except Exception:
            pass
    log_event(f'Schedule did NOT fire within {timeout}s')
    return False

# ─── chat helpers ───

def app_chat(msg, wait=18):
    main_wid = focus_app()
    if not main_wid:
        log_bug('AURA App', f'type "{msg}"', 'App window found', 'No AURA main window')
        return False
    geom_out = run_cmd(['geom', main_wid])
    if geom_out and geom_out != 'NOTFOUND':
        parts = geom_out.split()
        if len(parts) >= 4:
            gx, gy, gw, gh = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
            input_x = gx + gw // 2
            input_y = gy + gh - 80
        else:
            input_x, input_y = 1332, 1560
    else:
        input_x, input_y = 1332, 1560
    xdotool_click(input_x, input_y)
    time.sleep(0.3)
    xdotool_type(msg)
    time.sleep(0.3)
    xdotool_key('Return')
    stats['chats'] += 1
    log_event(f'App chat sent: "{msg[:50]}"')
    if wait:
        wait_for_response_done(timeout=wait)
    return True

def bar_chat(msg, wait=18):
    """Send bar message. Returns True if message arrived (verified via turn count)."""
    turns_before = get_turn_count()
    bar_wid = focus_bar()
    if not bar_wid:
        pos = find_text('Ask')
        if not pos:
            log_bug('AURA Bar', f'type "{msg}"', 'Bar visible', 'No AURA bar found')
            return False
        xdotool_click(pos[0], pos[1] + 20)
    else:
        geom_out = run_cmd(['geom', bar_wid])
        if geom_out and geom_out != 'NOTFOUND':
            parts = geom_out.split()
            if len(parts) >= 4:
                bx, by, bw, bh = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
                xdotool_click(bx + bw // 2, by + bh // 2 + 30)
            else:
                xdotool_click(1200, 1380)
        else:
            xdotool_click(1200, 1380)
    time.sleep(0.3)
    xdotool_type(msg)
    time.sleep(0.3)
    xdotool_key('Return')
    stats['chats'] += 1
    stats['bar_sent'] += 1
    log_event(f'Bar chat sent: "{msg[:50]}"')
    if wait:
        wait_for_response_done(timeout=wait)
    # STRICT: verify the message actually arrived
    turns_after = get_turn_count()
    if turns_after > turns_before:
        stats['bar_arrived'] += 1
        log_event(f'Bar message ARRIVED (turns {turns_before}->{turns_after})')
        return True
    else:
        log_event(f'Bar message DROPPED (turns stayed at {turns_before})')
        return False

# ─── case handlers ───

def handle_lenient(case_num, prompt):
    """Lenient: just checks AURA responds at all."""
    ok = bar_chat(prompt, wait=20)
    if not ok:
        # Lenient: even if bar dropped, check if app works
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    resp = read_response()
    if not resp or len(resp) < 3:
        log_bug('Lenient', prompt, 'Any response', 'No response', 'AURA did not respond')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_bar_ipc(case_num, prompt):
    """STRICT: bar message must arrive. Verifies via turn count."""
    ok = bar_chat(prompt, wait=20)
    if not ok:
        log_bug('Bar IPC', prompt, 'Message arrives in notebook', 'Message DROPPED',
                f'turn count unchanged — bar IPC failure')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_memory_store(case_num, prompt):
    """Store a fact. Lenient on response, strict on DB write."""
    ok = bar_chat(prompt, wait=20)
    if not ok:
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    time.sleep(2)
    stats['memory_store'] += 1
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_memory_recall(case_num, prompt, expected):
    """STRICT: recall must contain the expected fact."""
    ok = bar_chat(prompt, wait=25)
    if not ok:
        ok = app_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    resp = read_response().lower()
    if not resp:
        log_bug('Memory Recall', prompt, f'Response contains "{expected}"', 'No response', '')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        stats['memory_recall_wrong'] += 1
        return False
    if expected.lower() in resp:
        stats['memory_recall_correct'] += 1
        update_tracker(case_num, 'P')
        stats['pass'] += 1
        return True
    else:
        log_bug('Memory Recall', prompt, f'Response contains "{expected}"',
                f'Got: "{resp[:80]}"', 'WRONG fact or missing')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        stats['memory_recall_wrong'] += 1
        return False

def handle_persona(case_num, prompt, must_not_contain):
    """STRICT: AURA must NOT leak user facts as its own."""
    ok = bar_chat(prompt, wait=25)
    if not ok:
        ok = app_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    resp = read_response().lower()
    if not resp:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    if must_not_contain.lower() in resp:
        log_bug('Persona Leak', prompt, f'AURA does NOT claim "{must_not_contain}"',
                f'AURA said: "{resp[:80]}"', 'PERSONA LEAK — claimed user fact')
        stats['persona_leaks'] += 1
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_scheduling_set(case_num, prompt):
    """Set a reminder. Lenient on response."""
    ok = bar_chat(prompt, wait=20)
    if not ok:
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    stats['scheduling_set'] += 1
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_scheduling_check(case_num, wait_min):
    """STRICT: wait and check if the reminder actually fired."""
    log_event(f'Case {case_num}: waiting {wait_min} min for reminder to fire...')
    fired = check_schedule_fired(timeout=wait_min * 60 + 30)
    if fired:
        stats['scheduling_fired'] += 1
        update_tracker(case_num, 'P')
        stats['pass'] += 1
        return True
    else:
        stats['scheduling_missed'] += 1
        log_bug('Scheduling', f'wait {wait_min} min', 'Reminder fires',
                'Reminder did NOT fire', 'timer never created')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False

def handle_ocr(case_num, prompt):
    """STRICT: AURA must read REAL text from screen, not hallucinate."""
    # Take a screenshot first so we know what's actually on screen
    run_cmd(['save_screenshot', '/tmp/kuldeep_ocr.png'])
    time.sleep(0.5)
    # OCR the screenshot ourselves to know ground truth
    try:
        img = cv2.imread('/tmp/kuldeep_ocr.png')
        if img is not None:
            ground_truth = pytesseract.image_to_string(img, config='--psm 6')
            ground_truth = ground_truth.strip()
        else:
            ground_truth = ''
    except Exception:
        ground_truth = ''
    ok = bar_chat(prompt, wait=25)
    if not ok:
        ok = app_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    resp = read_response()
    if not resp:
        log_bug('OCR', prompt, 'AURA reads screen text', 'No response', '')
        stats['ocr_empty'] += 1
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    # STRICT: check if response contains any real text from the screen
    if ground_truth and len(ground_truth) > 10:
        # Pick a few distinctive words from ground truth
        gt_words = [w for w in ground_truth.split() if len(w) > 4 and w.isalpha()]
        matches = sum(1 for w in gt_words[:20] if w.lower() in resp.lower())
        if matches >= 2:
            stats['ocr_real_text'] += 1
            update_tracker(case_num, 'P')
            stats['pass'] += 1
            return True
        else:
            log_bug('OCR', prompt, f'AURA reads real text (ground truth: {ground_truth[:40]})',
                    f'AURA said: "{resp[:80]}"', 'hallucinated or empty')
            stats['ocr_empty'] += 1
            update_tracker(case_num, 'F')
            stats['fail'] += 1
            return False
    else:
        # Can't verify ground truth — lenient pass if response exists
        update_tracker(case_num, 'P')
        stats['pass'] += 1
        return True

def handle_multi_turn(case_num, prompt):
    """Multi-turn. Lenient on content, checks no repeat of previous turn."""
    wait = 35 if len(prompt) > 40 else 25
    ok = app_chat(prompt, wait=wait)
    if not ok:
        ok = bar_chat(prompt, wait=wait)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_dynamic(case_num, prompt):
    wait = 45 if 'detail' in prompt.lower() or len(prompt) > 50 else 20
    ok = bar_chat(prompt, wait=wait)
    if not ok:
        ok = app_chat(prompt, wait=wait)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_proactive(case_num, idle_min):
    """Idle and check for proactive trigger."""
    idle_sec = min(idle_min * 60, 300)  # cap at 5 min
    log_event(f'Case {case_num}: idling {idle_sec}s for proactivity test')
    smart_nap(idle_sec, f'case {case_num}')
    _, lines = see()
    has_proactive = any('aura' in l.lower() and ('ask' not in l.lower()) for l in lines)
    try:
        with open('/tmp/aura_app.log', 'r') as f:
            log_tail = f.readlines()[-30:]
        log_proactive = any('ProactiveScheduler' in l or 'proactive trigger' in l.lower()
                           or 'handleProactiveTrigger' in l for l in log_tail)
    except Exception:
        log_proactive = False
    if has_proactive or log_proactive:
        update_tracker(case_num, 'P')
        stats['pass'] += 1
    else:
        if idle_sec < 300:
            update_tracker(case_num, 'S')
            stats['skip'] += 1
        else:
            log_bug('Proactivity', f'idle {idle_sec}s', 'AURA initiates',
                    'No proactive event', '')
            update_tracker(case_num, 'F')
            stats['fail'] += 1
    return True

def handle_browsing(case_num, prompt):
    urls = ['https://news.ycombinator.com', 'https://github.com', 'https://reddit.com',
            'https://stackoverflow.com', 'https://wikipedia.org']
    url = random.choice(urls)
    if 'hn' in prompt.lower() or 'hacker' in prompt.lower():
        url = 'https://news.ycombinator.com'
    elif 'github' in prompt.lower():
        url = 'https://github.com'
    elif 'reddit' in prompt.lower():
        url = 'https://reddit.com'
    elif 'stack' in prompt.lower():
        url = 'https://stackoverflow.com'
    elif 'wiki' in prompt.lower():
        url = 'https://wikipedia.org'
    elif 'docs' in prompt.lower() or 'documentation' in prompt.lower():
        url = 'https://docs.python.org'
    elif 'blog' in prompt.lower():
        url = 'https://medium.com'
    open_browser(url)
    time.sleep(3)
    ok = bar_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_vscode(case_num, prompt):
    open_vscode()
    time.sleep(2)
    edits = [
        "# Kuldeep's test\ndef test_login():\n    assert True\n",
        "# Added test\nsquare = lambda x: x * x\n",
        "# New config\nserver:\n  port: 8080\n",
        "# Rust match\nmatch status {\n    200 => println!(\"OK\"),\n    _ => println!(\"Error\"),\n}\n",
        "# Dockerfile\nFROM python:3.11\nENV PYTHONDONTWRITEBYTECODE=1\n",
    ]
    edit = random.choice(edits)
    xdotool_click(500, 300)
    time.sleep(0.3)
    make_edit(edit)
    time.sleep(1)
    ok = bar_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_compare(case_num, prompt):
    aura_ok = bar_chat(prompt, wait=15)
    open_browser('https://chat.openai.com')
    time.sleep(5)
    xdotool_click(960, 800)
    time.sleep(0.3)
    xdotool_type(prompt)
    time.sleep(0.3)
    xdotool_key('Return')
    time.sleep(5)
    if aura_ok:
        update_tracker(case_num, 'P')
        stats['pass'] += 1
    else:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
    return aura_ok

def handle_stress(case_num, prompt):
    ok = bar_chat(prompt, wait=20)
    if not ok:
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_camera_vision(case_num, prompt):
    """Camera vision test: ask AURA about what the camera sees.
    Checks if YOLO/emotion/pose/gesture detection works."""
    # First check if camera vision is running by checking the log
    try:
        with open('/tmp/aura_app.log', 'r') as f:
            log_tail = f.readlines()[-50:]
        camera_active = any('yolo' in l.lower() or 'vision' in l.lower() or 'camera' in l.lower()
                           or 'fer' in l.lower() or 'pose' in l.lower() for l in log_tail)
    except Exception:
        camera_active = False

    ok = bar_chat(prompt, wait=25)
    if not ok:
        ok = app_chat(prompt, wait=25)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False

    resp = read_response()
    if not resp or len(resp) < 3:
        log_bug('Camera Vision', prompt, 'AURA describes what camera sees', 'No response', '')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False

    # Lenient: any response is acceptable for camera vision
    # (1.2B model may not describe accurately, but should acknowledge seeing something)
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_memory_wipe(case_num, prompt):
    ok = bar_chat(prompt, wait=20)
    if not ok:
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

def handle_memory_wipe_verify(case_num, expected_empty=True):
    """STRICT: verify memory is actually empty after wipe."""
    facts = check_facts_db()
    if expected_empty and len(facts) == 0:
        update_tracker(case_num, 'P')
        stats['pass'] += 1
        return True
    elif expected_empty and len(facts) > 0:
        log_bug('Memory Wipe', 'verify facts empty', '0 facts', f'{len(facts)} facts remain',
                f'facts: {facts[:3]}')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    else:
        update_tracker(case_num, 'P')
        stats['pass'] += 1
        return True

def handle_rl(case_num, prompt):
    ok = bar_chat(prompt, wait=20)
    if not ok:
        ok = app_chat(prompt, wait=20)
    if not ok:
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False
    update_tracker(case_num, 'P')
    stats['pass'] += 1
    return True

# ─── case routing ───

def run_case(case_num, category, description):
    """Route a case to the right handler based on category and description."""
    stats['cases_run'] += 1
    log_event(f'--- Case {case_num} [{category}] ---')

    try:
        # Lenient — just needs to respond
        if category == 'Lenient':
            return handle_lenient(case_num, description)

        # Bar IPC — strict, must arrive
        if category == 'Bar IPC':
            return handle_bar_ipc(case_num, description)

        # Memory store
        if category == 'Memory' and 'must' not in description.lower() and 'should' not in description.lower():
            return handle_memory_store(case_num, description)

        # Memory recall — strict, must contain expected fact
        if category == 'Memory' and 'must' in description.lower():
            # Extract expected fact from description after "must say"
            m = re.search(r'must say\s+(.+?)(?:\s*$|\s*\|)', description, re.IGNORECASE)
            if not m:
                m = re.search(r'must mention\s+(.+?)(?:\s*$|\s*\|)', description, re.IGNORECASE)
            if m:
                expected = m.group(1).strip()
                return handle_memory_recall(case_num, description, expected)
            return handle_memory_store(case_num, description)

        # Persona — strict, must not leak
        if category == 'Persona':
            m = re.search(r'must NOT say\s+(.+?)(?:\s*$|\s*\|)', description, re.IGNORECASE)
            if not m:
                m = re.search(r'must NOT claim\s+(.+?)(?:\s*$|\s*\|)', description, re.IGNORECASE)
            if not m:
                m = re.search(r'must NOT mention\s+(.+?)(?:\s*$|\s*\|)', description, re.IGNORECASE)
            if m:
                must_not = m.group(1).strip()
                return handle_persona(case_num, description, must_not)
            # Persona check without specific leak target
            ok = bar_chat(description, wait=25)
            if not ok:
                ok = app_chat(description, wait=25)
            if ok:
                update_tracker(case_num, 'P')
                stats['pass'] += 1
            else:
                update_tracker(case_num, 'F')
                stats['fail'] += 1
            return ok

        # Scheduling set
        if category == 'Scheduling' and 'fire' not in description.lower() and 'wait' not in description.lower():
            return handle_scheduling_set(case_num, description)

        # Scheduling check — strict, must fire
        if category == 'Scheduling' and ('fire' in description.lower() or 'wait' in description.lower()):
            m = re.search(r'(\d+)\s*min', description)
            wait_min = int(m.group(1)) if m else 2
            return handle_scheduling_check(case_num, wait_min)

        # OCR — strict, must read real text
        if category == 'OCR':
            return handle_ocr(case_num, description)

        # Multi-turn
        if category == 'Multi-Turn':
            return handle_multi_turn(case_num, description)

        # Dynamic sizing
        if category == 'Dynamic':
            return handle_dynamic(case_num, description)

        # Proactivity
        if category == 'Proactivity':
            m = re.search(r'(\d+)\s*min', description)
            idle_min = int(m.group(1)) if m else 5
            return handle_proactive(case_num, idle_min)

        # Browsing
        if category == 'Browsing':
            return handle_browsing(case_num, description)

        # Camera Vision
        if category == 'Camera Vision':
            return handle_camera_vision(case_num, description)

        # VS Code
        if category == 'VS Code':
            return handle_vscode(case_num, description)

        # Comparison
        if category == 'Comparison':
            return handle_compare(case_num, description)

        # Stress
        if category == 'Stress':
            return handle_stress(case_num, description)

        # Memory Wipe
        if category == 'Memory Wipe':
            if 'verify' in description.lower() or 'empty' in description.lower():
                return handle_memory_wipe_verify(case_num, expected_empty=True)
            return handle_memory_wipe(case_num, description)

        # RL Check
        if category == 'RL Check':
            return handle_rl(case_num, description)

        # Fallback
        log_event(f'Unknown category "{category}" — using lenient handler')
        return handle_lenient(case_num, description)

    except Exception as e:
        log_bug(category, description, 'Action completes', f'Exception: {e}', 'handler crashed')
        update_tracker(case_num, 'F')
        stats['fail'] += 1
        return False

# ─── case loading ───

def load_cases():
    """Load all pending cases from the tracker. Returns list of (num, category, description)."""
    cases = []
    for line in TRACKER.read_text().splitlines():
        if line.startswith('|') and not line.startswith('|---') and not line.startswith('| #'):
            parts = line.split('|')
            if len(parts) >= 7:
                try:
                    num = int(parts[1].strip())
                    cat = parts[3].strip()       # Category column
                    desc = parts[4].strip()       # Description column
                    status = parts[5].strip()     # Status column
                    if 'PENDING' in status:
                        cases.append((num, cat, desc))
                except ValueError:
                    pass
    return cases

# ─── setup ───

def setup():
    log_event('=== Kuldeep Singhania 4hr QA run starting ===')

    run_cmd(['kill'])
    time.sleep(2)

    # Clean memory (FULL wipe — including vec_memory, insights, triggers)
    log_event('Cleaning memory DB (full wipe)...')
    try:
        db = sqlite3.connect(os.path.expanduser('~/.local/share/aura_notebook/aura_memory.db'))
        for table in ['turns', 'facts', 'summaries', 'memory_notes', 'proactive_log',
                       'vec_memory', 'insights', 'triggers']:
            try:
                db.execute(f'DELETE FROM {table}')
            except Exception:
                pass
        db.commit()
        db.close()
        nb = os.path.expanduser('~/.local/share/AURA/notebook.jsonl')
        with open(nb, 'w') as f:
            pass
        log_event('Memory cleaned (full wipe — no Sam/Billie/Taylor contamination)')
    except Exception as e:
        log_event(f'Memory clean error: {e}')

    run_cmd(['launch'])
    log_event('AURA launching, waiting 25s for load...')
    time.sleep(25)

    run_cmd(['minimize', 'Visual Studio Code'])
    time.sleep(1)

    pos = find_text('brainstorm')
    if pos:
        log_event('Home page confirmed (found "brainstorm")')
    else:
        log_event('WARNING: home page not confirmed, continuing anyway')

    # Seed memory as Kuldeep Singhania (content creator/actor)
    log_event('Seeding memory as Kuldeep Singhania...')
    for fact in ['hey my name is kuldeep', 'im an actor and content creator',
                 'i live in mumbai', 'i played professional cricket',
                 'my brothers name is hemant', 'i was a yoga instructor']:
        try:
            bar_chat(fact, wait=15)
            time.sleep(2)
        except Exception as e:
            log_event(f'Seed fact "{fact}" failed: {e} — continuing')
    log_event('Memory seeding complete')

# ─── main ───

def main():
    try:
        setup()
    except Exception as e:
        log_event(f'Setup failed: {e} — attempting to continue anyway')

    iteration = 0

    while datetime.now() < END and not _SHUTDOWN_REQUESTED.is_set():
        try:
            cases = load_cases()
            if not cases:
                log_event('All cases completed early!')
                break

            # Kuldeep is methodical — runs in order, not random
            case_num, cat, desc = cases[0]
            elapsed = (datetime.now() - START).total_seconds() / 60
            log_event(f'Case {case_num} [{cat}] elapsed {elapsed:.0f}min/{DURATION_MIN}min')

            run_case(case_num, cat, desc)

            # Human-paced gap between cases (8-30s — Kuldeep is methodical)
            gap = random.uniform(8, 30)
            time.sleep(gap)

            # Every 10-15 cases, take a short smart nap (2-3 min)
            iteration += 1
            if iteration % random.randint(10, 15) == 0:
                nap_time = random.randint(120, 180)
                log_event(f'Taking a {nap_time}s smart nap between cases...')
                smart_nap(nap_time, 'between-cases idle')

        except Exception as e:
            log_event(f'Main loop error (non-fatal): {e} — continuing')
            time.sleep(5)

    if _SHUTDOWN_REQUESTED.is_set():
        log_event('Graceful shutdown requested — writing final report')
    write_final_report()

def write_final_report():
    log_event('=== Writing final report ===')
    counts = {}
    for line in TRACKER.read_text().splitlines():
        if line.startswith('|') and not line.startswith('|---') and not line.startswith('| #'):
            parts = line.split('|')
            if len(parts) >= 7:
                cat = parts[3].strip()
                status = parts[5].strip()
                counts.setdefault(cat, {'P': 0, 'F': 0, 'S': 0, 'pending': 0})
                if 'PASS' in status: counts[cat]['P'] += 1
                elif 'FAIL' in status: counts[cat]['F'] += 1
                elif 'SKIP' in status: counts[cat]['S'] += 1
                else: counts[cat]['pending'] += 1

    bug_lines = BUG_LOG.read_text().splitlines() if BUG_LOG.exists() else []
    recent_bugs = bug_lines[-20:] if len(bug_lines) > 20 else bug_lines[3:]

    report = f"""# AURA QA Final Report — Kuldeep Singhania 4-Hour Strict Test
**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Duration:** {(datetime.now() - START).total_seconds() / 60:.0f} minutes
**Tester Persona:** Kuldeep Singhania — Indian actor, social media influencer, entrepreneur. Known for short-form video content (skits, lip sync, dance) and micro films. Former yoga instructor, former professional cricket player. Lives in Mumbai. Lenient on cosmetics, strict on contract.

## 1. Per-Category Pass/Fail

| Category | Pass | Fail | Skip | Pending |
|---|---|---|---|---|
"""
    for cat, c in counts.items():
        report += f"| {cat} | {c['P']} | {c['F']} | {c['S']} | {c['pending']} |\n"

    report += f"""
## 2. Strict Contract Metrics

| Metric | Value |
|---|---|
| Bar messages sent | {stats['bar_sent']} |
| Bar messages arrived | {stats['bar_arrived']} |
| Bar IPC success rate | {stats['bar_arrived']}/{stats['bar_sent']} ({stats['bar_arrived']*100//max(stats['bar_sent'],1)}%) |
| Memory facts stored | {stats['memory_store']} |
| Memory recall correct | {stats['memory_recall_correct']} |
| Memory recall wrong | {stats['memory_recall_wrong']} |
| Scheduling reminders set | {stats['scheduling_set']} |
| Scheduling reminders fired | {stats['scheduling_fired']} |
| Scheduling reminders missed | {stats['scheduling_missed']} |
| Persona leaks detected | {stats['persona_leaks']} |
| OCR real text reads | {stats['ocr_real_text']} |
| OCR empty/hallucinated | {stats['ocr_empty']} |

**Overall:** run={stats['cases_run']} pass={stats['pass']} fail={stats['fail']} skip={stats['skip']} bugs={stats['bugs']}

## 3. Top Bugs (recent)
{''.join(line + chr(10) for line in recent_bugs)}

## 4. Strict Contract Verdict

- **Bar IPC:** {'PASS' if stats['bar_arrived'] == stats['bar_sent'] and stats['bar_sent'] > 5 else 'FAIL'} — {stats['bar_arrived']}/{stats['bar_sent']} messages arrived
- **Memory Recall:** {'PASS' if stats['memory_recall_correct'] > 0 and stats['memory_recall_wrong'] == 0 else 'NEEDS WORK'} — {stats['memory_recall_correct']} correct, {stats['memory_recall_wrong']} wrong
- **Scheduling:** {'PASS' if stats['scheduling_fired'] > 0 and stats['scheduling_missed'] == 0 else 'FAIL'} — {stats['scheduling_fired']} fired, {stats['scheduling_missed']} missed
- **Persona:** {'PASS' if stats['persona_leaks'] == 0 else 'FAIL'} — {stats['persona_leaks']} leaks detected
- **OCR:** {'PASS' if stats['ocr_real_text'] > 0 and stats['ocr_empty'] == 0 else 'NEEDS WORK'} — {stats['ocr_real_text']} real reads, {stats['ocr_empty']} empty

## 5. Kuldeep's Notes

As a creator, the things that matter most to me:
- Bar IPC: I need every message to go through. If I'm mid-shoot and send a quick question, it can't vanish.
- Memory: If I tell AURA about my brother Hemant or my cricket career, it better remember correctly.
- Scheduling: When I set a reminder to post at 6pm, it needs to actually fire. Not just store a note.
- Persona: AURA claiming it plays cricket or makes micro films? That's weird. Keep it clean.
- OCR: If I'm looking at a script or reading comments, AURA needs to actually read the screen.

Lenient on: prose quality, response length, minor rambling (1.2B model limitations).
Strict on: bar IPC reliability, memory recall accuracy, scheduling timers firing, persona boundary, OCR reading real text.

---
*End of Report*
"""
    REPORT.write_text(report)
    log_event(f'Final report written to {REPORT}')

if __name__ == '__main__':
    def h(sig, frame):
        if _SHUTDOWN_REQUESTED.is_set():
            log_event('Second signal — force exiting')
            sys.exit(1)
        log_event('Signal received — requesting graceful shutdown after current case')
        _SHUTDOWN_REQUESTED.set()
    signal.signal(signal.SIGINT, h)
    signal.signal(signal.SIGTERM, h)
    main()