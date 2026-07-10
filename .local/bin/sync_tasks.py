#!/usr/bin/env python3

import os
import sys
import time
import re
import gspread
import yaml
import subprocess
from google.oauth2.service_account import Credentials
from datetime import datetime

# --- КОНФІГУРАЦІЯ ---
VAULT_PATH = "/home/user/Documents/.wiki"
CREDENTIALS_JSON = "/home/user/.local/bin/credentials.json"
TAB_NAME = "Задачі"  # Назва аркушу зафіксована назавжди
MIN_INTERVAL = 3600
PID_FILE = "/tmp/sync_tasks_obsidian.pid"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(SCRIPT_DIR, "sync_tasks.log")

if "DBUS_SESSION_BUS_ADDRESS" not in os.environ:
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{os.getuid()}/bus"
os.environ["DISPLAY"] = os.environ.get("DISPLAY", ":0")

scope = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"]

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] {message}\n")
    print(message)

def check_single_instance():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            print("Скрипт уже запущений в іншому процесі.")
            sys.exit(0)
        except (OSError, ValueError):
            os.remove(PID_FILE)
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

def check_interval():
    if "--force" in sys.argv:
        return True
    if os.path.exists(LOG_FILE) and os.path.getsize(LOG_FILE) > 0:
        if time.time() - os.path.getmtime(LOG_FILE) < MIN_INTERVAL:
            return False
    return True

def read_frontmatter(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            content = f.read()
        if content.startswith("---"):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                meta = yaml.safe_load(parts[1]) or {}
                return meta, parts[2]
    except Exception as e:
        log_message(f"[X] Помилка читання файлу {os.path.basename(path)}: {e}")
    return {}, content

def clean_task_text(text):
    text = re.sub(r'🆔\s*\w+', '', text)
    text = re.sub(r'\[\[([^\]]+)\]\]', lambda m: m.group(1).split('|')[-1], text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'✅\s*\d{4}-\d{2}-\d{2}', '', text)
    text = re.sub(r'🔁.*$', '', text)
    return text.strip()

def sync_note_to_sheet(note_path, client):
    meta, content = read_frontmatter(note_path)
    sheet_id = meta.get("sheet_id")

    if not sheet_id:
        return False

    try:
        sheet = client.open_by_key(sheet_id)
        try:
            worksheet = sheet.worksheet(TAB_NAME)
        except gspread.exceptions.WorksheetNotFound:
            worksheet = sheet.add_worksheet(title=TAB_NAME, rows=1000, cols=5)

        worksheet.clear()
        worksheet.append_row(["Статус", "Задача", "Завершено"])

        rows = []
        for line in content.splitlines():
            line = line.strip()
            if not re.match(r'^(> *)?- \[[ xX]\]', line):
                continue
            
            is_done = "[x]" in line.lower()
            status = "✅" if is_done else "❌"
            text = re.sub(r'^(> *)?- \[[ xX]\]\s*(#task\s*)?', '', line)
            
            completed_date = ""
            match = re.search(r'✅\s*(\d{4}-\d{2}-\d{2})', text)
            if is_done and match:
                try:
                    completed_date = datetime.strptime(match.group(1), "%Y-%m-%d").strftime("%d.%m.%Y")
                except ValueError:
                    completed_date = match.group(1)

            rows.append([status, clean_task_text(text), completed_date])

        if rows:
            worksheet.append_rows(rows, value_input_option='USER_ENTERED')
        
        log_message(f"[✓] Успішно синхронізовано: {os.path.basename(note_path)}")
        return True
    except Exception as e:
        log_message(f"[X] Помилка API для {os.path.basename(note_path)}: {e}")
        return False

def main():
    check_single_instance()
    
    if not check_interval():
        print("Пропущено: інтервал в 1 годину ще не минув. Використовуйте --force для запуску.")
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        return

    try:
        if not os.path.exists(CREDENTIALS_JSON):
            log_message(f"[CRITICAL] Файл сервісного акаунта не знайдено: {CREDENTIALS_JSON}")
            return

        if not os.path.exists(VAULT_PATH):
            log_message(f"[CRITICAL] Шлях до ваулту не існує: {VAULT_PATH}")
            return

        print("Підключення до Google API...")
        creds = Credentials.from_service_account_file(CREDENTIALS_JSON, scopes=scope)
        client = gspread.authorize(creds)
        
        count = 0
        for file in os.listdir(VAULT_PATH):
            if file.endswith(".md"):
                path = os.path.join(VAULT_PATH, file)
                meta, _ = read_frontmatter(path)
                if "sheet_id" in meta:
                    if sync_note_to_sheet(path, client):
                        count += 1

        if count > 0:
            log_message(f"Завершено успішно. Оброблено нотаток: {count}")
            # Оновлюємо mtime файлу логу тільки після УСПІШНОЇ синхронізації
            os.utime(LOG_FILE, None)
            try:
                subprocess.run(["notify-send", "-u", "low", "Синхронізація задач", f"Успішно: {count} нотаток"], check=False)
            except FileNotFoundError:
                pass
        else:
            print("Жоден файл не було оновлено або не знайдено міток sheet_id.")
            
    except Exception as e:
        log_message(f"[CRITICAL] Помилка ініціалізації: {e}")
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)

if __name__ == "__main__":
    main()
