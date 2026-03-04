#!/usr/bin/env python3
"""Minimal Whisper REST API for Buoy – POST /asr with audio, returns transcribed text."""
import io
import sys
from pathlib import Path

# faster-whisper is optional; fail gracefully if not installed
try:
    from faster_whisper import WhisperModel
except ImportError:
    WhisperModel = None

def create_app():
    try:
        from fastapi import FastAPI, HTTPException, Request
        from fastapi.responses import PlainTextResponse
    except ImportError:
        print("fastapi/uvicorn not installed; use: pip install fastapi uvicorn", file=sys.stderr)
        sys.exit(1)

    app = FastAPI(title="Buoy Whisper ASR")

    model = None

    @app.on_event("startup")
    async def load_model():
        global model
        if WhisperModel is None:
            return
        # Use tiny model for Pi (8GB shared with Ollama); tiny ~75MB, small ~500MB
        model_path = Path(__file__).parent / "whisper_models"
        model_path.mkdir(exist_ok=True)
        model = WhisperModel("tiny", device="cpu", compute_type="int8", download_root=str(model_path))

    @app.post("/asr", response_class=PlainTextResponse)
    async def transcribe(request: Request):
        if model is None:
            raise HTTPException(status_code=503, detail="Whisper model not loaded")
        # Accept raw POST body (LLM node sends decoded audio bytes)
        data = await request.body()
        if not data:
            raise HTTPException(status_code=400, detail="No audio data")
        segments, _ = model.transcribe(io.BytesIO(data), language=None)
        text = " ".join(s.text for s in segments).strip()
        return text

    @app.get("/health")
    async def health():
        return {"status": "ok", "model_loaded": model is not None}

    return app

if __name__ == "__main__":
    import uvicorn
    app = create_app()
    uvicorn.run(app, host="0.0.0.0", port=9000)
