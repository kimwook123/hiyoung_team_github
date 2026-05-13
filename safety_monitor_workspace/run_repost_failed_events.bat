@echo off
cd /d "%~dp0safety_ai_monitor"
echo Reposting failed events from fallback JSONL...
py -3.12 tools\repost_failed_events.py
pause
