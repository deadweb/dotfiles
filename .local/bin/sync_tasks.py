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
TASKS_TAB_NAME = "Задачі"
PROJECTS_TAB_NAME = "Проєкти"
MIN_INTERVAL = 3600
PID_FILE = "/tmp/sync_tasks_obsidian.pid"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(SCRIPT_DIR, "sync_tasks.log")

if "DBUS_SESSION_BUS_ADDRESS" not in os.environ:
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{os.getuid()}/bus"
os.environ["DISPLAY"] = os.environ.get("DISPLAY", ":0")

scope = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"]

DEFAULT_PROJECT_HEADERS = [
    "Назва проєкту", "Статус", "ID акаунту", "Сайт", "Дата початку", "Дата закінчення", 
    "Бюджет", "Опис", "Галузь", "Гео", "Кейс"
]

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

def extract_sheet_id(meta):
    sheet_id = meta.get("sheet_id")
    if sheet_id:
        return str(sheet_id).strip()
    
    case_url = meta.get("case")
    if case_url and isinstance(case_url, str):
        match = re.search(r'/d/([a-zA-Z0-9-_]+)', case_url)
        if match:
            return match.group(1)
            
    return None

def is_active_note(meta):
    status = meta.get("status")
    if isinstance(status, str) and status.strip().lower() == "активно":
        return True
    return False

def clean_text(text):
    if not text:
        return ""
    text = str(text)
    text = re.sub(r'🆔\s*\w+', '', text)
    text = re.sub(r'\[\[([^\]]+)\]\]', lambda m: m.group(1).split('|')[-1], text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'✅\s*\d{4}-\d{2}-\d{2}', '', text)
    text = re.sub(r'🔁.*$', '', text)
    return text.strip()

def parse_company_variants(val):
    if not val:
        return []
    raw = str(val).strip().strip('"').strip("'")
    match = re.search(r'\[\[([^\]]+)\]\]', raw)
    if match:
        inner = match.group(1)
        return [p.strip().lower() for p in inner.split('|')]
    return [raw.lower()]

def clean_val(val):
    if val is None:
        return ""
    if isinstance(val, list):
        return ", ".join(clean_val(v) for v in val)
    return clean_text(val)

def format_budget(meta):
    budget_raw = meta.get("budget")
    currency_raw = meta.get("currency", "")
    
    if budget_raw is None or budget_raw == "":
        return ""
    
    try:
        daily_budget = float(budget_raw)
        monthly_budget = int(daily_budget * 30)
        curr = clean_val(currency_raw)
        return f"{curr}{monthly_budget}" if curr else str(monthly_budget)
    except (ValueError, TypeError):
        return clean_val(budget_raw)

def sync_tasks_for_note(sheet, content):
    """Вивантажує списки задач нотатки в аркуш 'Задачі'."""
    try:
        try:
            worksheet = sheet.worksheet(TASKS_TAB_NAME)
        except gspread.exceptions.WorksheetNotFound:
            worksheet = sheet.add_worksheet(title=TASKS_TAB_NAME, rows=1000, cols=5)

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

            rows.append([status, clean_text(text), completed_date])

        if rows:
            worksheet.append_rows(rows, value_input_option='USER_ENTERED')
            
        return True
    except Exception as e:
        return False

def sync_projects_smart_update(sheet, projects_data):
    """
    Оновлює аркуш 'Проєкти' без повного перезапису.
    Автоматично виявляє та доповнює відсутні колонки в заголовку.
    """
    try:
        try:
            worksheet = sheet.worksheet(PROJECTS_TAB_NAME)
        except gspread.exceptions.WorksheetNotFound:
            worksheet = sheet.add_worksheet(title=PROJECTS_TAB_NAME, rows=100, cols=15)

        all_values = worksheet.get_all_values()

        if not all_values or not all_values[0]:
            headers = DEFAULT_PROJECT_HEADERS
        else:
            headers = [h.strip() for h in all_values[0] if h.strip()]
            for required_header in DEFAULT_PROJECT_HEADERS:
                if required_header not in headers:
                    headers.append(required_header)

        header_map = {h: i for i, h in enumerate(headers)}
        new_table_rows = [headers]

        for proj in projects_data:
            row_dict = {
                "Назва проєкту": proj.get("name", ""),
                "Статус": proj.get("status", "Активно"),
                "ID акаунту": proj.get("account_id", ""),
                "Сайт": proj.get("site", ""),
                "Дата початку": proj.get("sday", ""),
                "Дата закінчення": proj.get("eday", ""),
                "Бюджет": proj.get("budget", ""),
                "Опис": proj.get("description", ""),
                "Галузь": proj.get("industry", ""),
                "Гео": proj.get("geo", ""),
                "Кейс": proj.get("case", "")
            }

            row_cells = [""] * len(headers)
            for h_name, col_idx in header_map.items():
                if h_name in row_dict:
                    row_cells[col_idx] = row_dict[h_name]

            new_table_rows.append(row_cells)

        worksheet.update(range_name="A1", values=new_table_rows, value_input_option='USER_ENTERED')
        
        if len(all_values) > len(new_table_rows):
            empty_tail = [[""] * len(headers)] * (len(all_values) - len(new_table_rows))
            start_clear_row = len(new_table_rows) + 1
            worksheet.update(range_name=f"A{start_clear_row}", values=empty_tail)

    except Exception as e:
        log_message(f"[X] Помилка смарт-оновлення проєктів: {e}")

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

        all_files = [f for f in os.listdir(VAULT_PATH) if f.endswith(".md")]
        
        agency_sheets = {}
        project_notes = []
        tasks_count = 0

        # КРОК 1: Задачі
        for file in all_files:
            path = os.path.join(VAULT_PATH, file)
            meta, content = read_frontmatter(path)
            
            sheet_id = extract_sheet_id(meta)
            
            if sheet_id:
                names = [file.replace(".md", "")]
                if meta.get("name"):
                    names.append(str(meta.get("name")))
                if meta.get("aliases"):
                    aliases = meta.get("aliases")
                    if isinstance(aliases, list):
                        names.extend([str(a) for a in aliases])
                    else:
                        names.append(str(aliases))
                
                for name in names:
                    agency_sheets[name.strip().lower()] = sheet_id

            if is_active_note(meta) and sheet_id:
                try:
                    sheet = client.open_by_key(sheet_id)
                    if sync_tasks_for_note(sheet, content):
                        log_message(f"[✓] Успішно синхронізовано: {file}")
                        tasks_count += 1
                except Exception as e:
                    log_message(f"[X] Помилка API для {file}: {e}")

            project_notes.append((meta, file))

        # КРОК 2: Проєкти
        table_data = {}

        for meta, note_file in project_notes:
            company_raw = meta.get("company")
            if not company_raw:
                continue

            company_variants = parse_company_variants(company_raw)
            
            target_sheet_id = None
            for variant in company_variants:
                if variant in agency_sheets:
                    target_sheet_id = agency_sheets[variant]
                    break

            if target_sheet_id:
                if target_sheet_id not in table_data:
                    table_data[target_sheet_id] = []

                proj_dict = {
                    "name": clean_val(meta.get("name", note_file.replace(".md", ""))),
                    "status": clean_val(meta.get("status", "Активно")),
                    "account_id": clean_val(meta.get("account_id")),
                    "site": clean_val(meta.get("site")),
                    "sday": clean_val(meta.get("sday")),
                    "eday": clean_val(meta.get("eday")),
                    "budget": format_budget(meta),
                    "description": clean_val(meta.get("description")),
                    "industry": clean_val(meta.get("industry")),
                    "geo": clean_val(meta.get("geo")),
                    "case": clean_val(meta.get("case"))
                }
                table_data[target_sheet_id].append(proj_dict)

        for sheet_id, projects in table_data.items():
            try:
                sheet = client.open_by_key(sheet_id)
                sync_projects_smart_update(sheet, projects)
            except Exception as e:
                log_message(f"[X] Помилка оновлення проєктів ({sheet_id}): {e}")

        if tasks_count > 0:
            log_message(f"Завершено успішно. Оброблено нотаток: {tasks_count}")
            os.utime(LOG_FILE, None)
            try:
                subprocess.run(["notify-send", "-u", "low", "Синхронізація задач", f"Успішно: {tasks_count} нотаток"], check=False)
            except FileNotFoundError:
                pass
        else:
            print("Жоден файл не було оновлено (немає активних нотаток із sheet_id/case).")

    except Exception as e:
        log_message(f"[CRITICAL] Помилка ініціалізації: {e}")
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)

if __name__ == "__main__":
    main()
