#!/usr/bin/env bash
# Region select -> screenshot -> RapidOCR (PP-OCRv6, ONNX) -> clipboard.
# Needs: python-rapidocr (AUR) + python-onnxruntime-cpu, models bundled.

GEOMETRY=$(slurp) || exit 1
[ -z "$GEOMETRY" ] && exit 1

notify-send -t 1000 "OCR" "Processing..."

# Det limit_type "max": the default "min" upscales short, wide captures ~10x
# before detection (1.8 s -> 0.2 s). cls off: screen text is never rotated.
TEXT=$(grim -g "$GEOMETRY" - | /usr/bin/python -c '
import sys
from rapidocr import RapidOCR
ocr = RapidOCR(params={
    "Global.log_level": "critical",
    "Global.use_cls": False,
    "Det.limit_type": "max",
    "Det.limit_side_len": 1280,
    "EngineConfig.onnxruntime.intra_op_num_threads": 6,
})
r = ocr(sys.stdin.buffer.read())
print("\n".join(r.txts or []))
' 2>/dev/null)

if [ -z "$TEXT" ]; then
	notify-send "OCR" "No text detected."
	exit 1
fi

printf '%s' "$TEXT" | wl-copy
notify-send "OCR" "Text copied to clipboard!"
