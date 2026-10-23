from __future__ import annotations

import base64
import json
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from ultralytics import YOLO


ROOT = Path(__file__).resolve().parent
MODEL_CANDIDATES = (
    ROOT / "runs" / "classify" / "sugarcane-classifier" / "weights" / "best.pt",
)
MODEL_PATH = next((path for path in MODEL_CANDIDATES if path.is_file()), None)
if MODEL_PATH is None:
    raise FileNotFoundError("Train the model before starting the prediction server.")

MODEL = YOLO(str(MODEL_PATH))


class PredictionHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path in {"/", "/health"}:
            self._send_json({"status": "ok", "service": "sugarcane prediction server"})
            return
        self._send_json({"error": "Endpoint not found."}, 404)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_POST(self) -> None:
        if self.path != "/predict":
            self._send_json({"error": "Endpoint not found."}, 404)
            return

        try:
            size = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(size))
            image_data = base64.b64decode(payload["image"], validate=True)
            suffix = payload.get("extension", ".jpg")
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as image_file:
                image_file.write(image_data)
                image_path = image_file.name

            result = MODEL.predict(source=image_path, verbose=False)[0]
            if result.probs is None:
                raise RuntimeError("The model did not return a classification.")
            class_name = result.names[result.probs.top1]
            confidence = float(result.probs.top1conf)
            self._send_json({"className": class_name, "confidence": confidence})
        except (KeyError, ValueError, json.JSONDecodeError, OSError, RuntimeError) as error:
            self._send_json({"error": str(error)}, 400)

    def log_message(self, format: str, *args: object) -> None:
        return

    def _send_json(self, payload: dict[str, object], status: int = 200) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")


if __name__ == "__main__":
    print("Prediction server listening at http://127.0.0.1:8000")
    ThreadingHTTPServer(("127.0.0.1", 8000), PredictionHandler).serve_forever()
