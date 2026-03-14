#!/bin/sh
# Run Whisper; on crash, sleep 30s before exit to avoid restart hammering
python -m uvicorn whisper_server:create_app --factory --host 0.0.0.0 --port 9000 || { sleep 30; exit 1; }
