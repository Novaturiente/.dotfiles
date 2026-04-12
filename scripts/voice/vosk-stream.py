#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["vosk", "sounddevice"]
# ///

"""Vosk streaming STT bridge. Captures mic audio, prints recognized text to stdout."""

import sys
import os
import json
import queue
import signal
import sounddevice as sd
from vosk import Model, KaldiRecognizer

SAMPLE_RATE = 16000
MODEL_PATH = os.path.expanduser("~/.local/share/vosk/model-en-small")

audio_queue = queue.Queue()

def audio_callback(indata, frames, time, status):
    if status:
        print(f"audio warning: {status}", file=sys.stderr)
    audio_queue.put(bytes(indata))

def main():
    # --check flag: verify model and deps exist, then exit
    if "--check" in sys.argv:
        if not os.path.isdir(MODEL_PATH):
            print(f"Model not found at {MODEL_PATH}", file=sys.stderr)
            sys.exit(1)
        Model(MODEL_PATH)
        print("vosk-stream: model and dependencies OK")
        sys.exit(0)

    if not os.path.isdir(MODEL_PATH):
        print(f"Error: Vosk model not found at {MODEL_PATH}", file=sys.stderr)
        print("Run setup.sh to download the model.", file=sys.stderr)
        sys.exit(1)

    model = Model(MODEL_PATH)
    recognizer = KaldiRecognizer(model, SAMPLE_RATE)

    # Exit cleanly on SIGTERM
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    # Unbuffered stdout so the shell daemon gets lines immediately
    sys.stdout.reconfigure(line_buffering=True)

    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=4000,
        dtype="int16",
        channels=1,
        callback=audio_callback,
    ):
        while True:
            data = audio_queue.get()
            if recognizer.AcceptWaveform(data):
                result = json.loads(recognizer.Result())
                text = result.get("text", "").strip()
                if text:
                    print(text, flush=True)

if __name__ == "__main__":
    main()
