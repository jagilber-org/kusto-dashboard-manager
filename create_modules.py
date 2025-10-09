
import os

os.chdir(r"c:\github\jagilber\kusto-dashboard-manager\src")

# Create utils.py
with open("utils.py", "w", encoding="utf-8") as f:
    f.write("""#Utils module
import json
import logging
from pathlib import Path
from datetime import datetime

class Logger:
    def __init__(self, enabled=False, log_file=None, level="INFO"):
        self.enabled = enabled
        self.log_file = log_file
        self.level = level
        if enabled:
            self.logger = logging.getLogger("kdm")
            self.logger.setLevel(getattr(logging, level))
            if log_file:
                Path(log_file).parent.mkdir(parents=True, exist_ok=True)
                fh = logging.FileHandler(log_file)
                self.logger.addHandler(fh)
        else:
            self.logger = None
    
    def log(self, level, message, **kwargs):
        if self.enabled and self.logger:
            entry = {"timestamp": datetime.utcnow().isoformat(), "level": level, "message": message, **kwargs}
            getattr(self.logger, level.lower(), self.logger.info)(json.dumps(entry))
    
    def debug(self, msg, **kw): self.log("DEBUG", msg, **kw)
    def info(self, msg, **kw): self.log("INFO", msg, **kw)
    def warning(self, msg, **kw): self.log("WARNING", msg, **kw)
    def error(self, msg, **kw): self.log("ERROR", msg, **kw)

_global_logger = None
def get_logger(): 
    global _global_logger
    if _global_logger is None: _global_logger = Logger(enabled=False)
    return _global_logger
def set_logger(logger): 
    global _global_logger
    _global_logger = logger

def validate_dashboard_url(url):
    if not url: return False
    prefix = "https://dataexplorer.azure.com/dashboards/"
    if not url.startswith(prefix): return False
    dashboard_id = url[len(prefix):].split("/")[0].split("?")[0]
    return len(dashboard_id) >= 5

def validate_json_file(file_path):
    path = Path(file_path)
    if not path.exists() or not path.is_file(): return False
    try:
        with open(path, "r", encoding="utf-8") as f: json.load(f)
        return True
    except: return False

def validate_dashboard_json(data):
    if not all(f in data for f in ["name", "version", "tiles"]): return False
    if not isinstance(data["tiles"], list): return False
    for tile in data["tiles"]:
        if not isinstance(tile, dict) or not all(f in tile for f in ["id", "type"]): return False
    return True

def ensure_directory(path): Path(path).mkdir(parents=True, exist_ok=True)

def read_json_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f: return json.load(f)

def write_json_file(file_path, data, indent=2):
    ensure_directory(str(Path(file_path).parent))
    with open(file_path, "w", encoding="utf-8") as f: json.dump(data, f, indent=indent, ensure_ascii=False)

def format_error(error): return f"{error.__class__.__name__}: {str(error)}"
def print_success(msg): print(f"[+] {msg}")
def print_error(msg): print(f"[!] {msg}")
def print_info(msg): print(f"[i] {msg}")
def print_header(title): print(f"\\n{title}\\n{'='*len(title)}")
""")

print("Created utils.py")
