from __future__ import annotations

from datetime import datetime
import os
import sys


_ANSI_RESET = "\033[0m"
_TAG_COLORS = {
    "REQ": "\033[96m",
    "REQ-SUM": "\033[36m",
    "SRC": "\033[94m",
    "PROGRESS": "\033[92m",
    "PERF": "\033[95m",
    "WARN": "\033[93m",
    "ERROR": "\033[91m",
    "MODEL": "\033[90m",
}


def _enable_windows_ansi() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    if os.name != "nt":
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        if handle == 0 or handle == -1:
            return False
        mode = ctypes.c_uint()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)) == 0:
            return False
        enable_vt = 0x0004
        if mode.value & enable_vt:
            return True
        if kernel32.SetConsoleMode(handle, mode.value | enable_vt) == 0:
            return False
        return True
    except Exception:
        return False


_USE_COLOR = _enable_windows_ansi()


def _format_value(value: object) -> str:
    if value is None:
        return "-"
    text = str(value).strip()
    return text if text else "-"


def _build_field_text(fields: dict[str, object]) -> str:
    parts: list[str] = []
    for key, value in fields.items():
        if value is None:
            continue
        parts.append(f"{key}={_format_value(value)}")
    return " ".join(parts)


def log_line(tag: str, message: str = "", **fields: object) -> None:
    timestamp = datetime.now().strftime("%H:%M:%S")
    prefix = f"[{timestamp}] [{tag}]"
    if _USE_COLOR:
        color = _TAG_COLORS.get(tag, "")
        if color:
            prefix = f"{color}{prefix}{_ANSI_RESET}"
    field_text = _build_field_text(fields)
    if message and field_text:
        print(f"{prefix} {message} {field_text}", flush=True)
        return
    if message:
        print(f"{prefix} {message}", flush=True)
        return
    if field_text:
        print(f"{prefix} {field_text}", flush=True)
        return
    print(prefix, flush=True)
