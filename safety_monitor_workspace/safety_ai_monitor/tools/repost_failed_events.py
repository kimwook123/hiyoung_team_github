import json
import sys
from pathlib import Path

import requests


PROJECT_DIR = Path(__file__).resolve().parents[1]
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

from config import (  # noqa: E402
    EVENT_POST_TIMEOUT_SECONDS,
    EVENT_POST_URL,
    HTTP_EVENT_FALLBACK_JSON_PATH,
)


SUCCESS_LOG_PATH = "logs/events_post_reposted_success.jsonl"
FAILED_LOG_PATH = "logs/events_post_repost_failed.jsonl"


def main() -> None:
    input_path = _to_project_path(HTTP_EVENT_FALLBACK_JSON_PATH)
    success_path = _to_project_path(SUCCESS_LOG_PATH)
    failed_path = _to_project_path(FAILED_LOG_PATH)

    total = 0
    success = 0
    failed = 0
    skipped = 0

    success_lines: list[str] = []
    failed_lines: list[str] = []

    if not input_path.exists():
        print(f"fallback file not found: {input_path}")
        print("total=0 success=0 failed=0 skipped=0")
        return

    with input_path.open("r", encoding="utf-8") as input_file:
        for line_number, line in enumerate(input_file, start=1):
            raw_line = line.strip()
            if not raw_line:
                skipped += 1
                continue

            total += 1

            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError as error:
                failed += 1
                failed_lines.append(
                    _to_json_line(
                        {
                            "line_number": line_number,
                            "error": f"json_decode_error: {error}",
                            "raw_line": raw_line,
                        }
                    )
                )
                continue

            if not isinstance(record, dict):
                failed += 1
                failed_lines.append(
                    _to_json_line(
                        {
                            "line_number": line_number,
                            "error": "event record is not a dict",
                            "raw_record": record,
                        }
                    )
                )
                continue

            try:
                response = requests.post(
                    EVENT_POST_URL,
                    json=record,
                    timeout=EVENT_POST_TIMEOUT_SECONDS,
                )
                if 200 <= response.status_code < 300:
                    success += 1
                    success_lines.append(_to_json_line(record))
                else:
                    failed += 1
                    failed_lines.append(
                        _to_json_line(
                            {
                                "line_number": line_number,
                                "status_code": response.status_code,
                                "item": record,
                            }
                        )
                    )
            except requests.RequestException as error:
                failed += 1
                failed_lines.append(
                    _to_json_line(
                        {
                            "line_number": line_number,
                            "error": str(error),
                            "item": record,
                        }
                    )
                )

    _write_lines(success_path, success_lines)
    _write_lines(failed_path, failed_lines)

    print(f"input_file={input_path}")
    print(f"success_log={success_path}")
    print(f"failed_log={failed_path}")
    print(f"total={total}")
    print(f"success={success}")
    print(f"failed={failed}")
    print(f"skipped={skipped}")


def _to_project_path(relative_path: str) -> Path:
    return (PROJECT_DIR / relative_path).resolve()


def _to_json_line(data: object) -> str:
    return json.dumps(data, ensure_ascii=False) + "\n"


def _write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output_file:
        output_file.writelines(lines)


if __name__ == "__main__":
    main()
