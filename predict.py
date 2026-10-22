from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parent
MODEL_CANDIDATES = (
    PROJECT_ROOT / "runs" / "classify" / "sugarcane-classifier" / "weights" / "best.pt",
    PROJECT_ROOT
    / "runs"
    / "classify"
    / "runs"
    / "sugarcane-classifier"
    / "weights"
    / "best.pt",
)
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Classify sugarcane disease images.")
    parser.add_argument("--source", required=True, help="Image file or folder of images.")
    parser.add_argument(
        "--model",
        help="Optional model path. If omitted, use the latest trained model.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = Path(args.source).expanduser().resolve()
    model_path = (
        Path(args.model).expanduser().resolve()
        if args.model
        else next((path for path in MODEL_CANDIDATES if path.is_file()), None)
    )

    if not source.exists():
        raise FileNotFoundError(f"Prediction source does not exist: {source}")
    if model_path is None or not model_path.is_file():
        raise FileNotFoundError(
            "No trained model was found. Train first with: "
            ".venv\\Scripts\\python.exe train.py"
        )

    if source.is_dir():
        direct_images = [
            path for path in source.iterdir()
            if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
        ]
        prediction_source = (
            direct_images
            if direct_images
            else [
                path for path in source.rglob("*")
                if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
            ]
        )
        if not prediction_source:
            raise FileNotFoundError(f"No supported images found under: {source}")
    else:
        if source.suffix.lower() not in IMAGE_EXTENSIONS:
            raise ValueError(
                f"Unsupported image format: {source.suffix}. "
                f"Use one of: {', '.join(sorted(IMAGE_EXTENSIONS))}"
            )
        prediction_source = str(source)

    model = YOLO(str(model_path))
    results = model.predict(
        source=prediction_source,
        save=True,
        project=str(PROJECT_ROOT / "runs" / "classify"),
        name="predictions",
        exist_ok=True,
    )

    for result in results:
        if result.probs is not None:
            top_class = result.names[result.probs.top1]
            confidence = float(result.probs.top1conf)
            print(f"{result.path}: {top_class} ({confidence:.2%})")


if __name__ == "__main__":
    main()
