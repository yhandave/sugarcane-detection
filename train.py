from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parent
DATASET_DIR = PROJECT_ROOT / "dataset"
DEFAULT_MODEL = PROJECT_ROOT / "yolo11n-cls.pt"
OUTPUT_DIR = PROJECT_ROOT / "runs" / "classify"
TRAINED_MODEL = OUTPUT_DIR / "sugarcane-classifier" / "weights" / "best.pt"
LEGACY_TRAINED_MODEL = (
    OUTPUT_DIR / "runs" / "sugarcane-classifier" / "weights" / "best.pt"
)
EXPECTED_CLASSES = {
    "Brown Spot",
    "Grassy Shoot",
    "Healthy",
    "Mosaic",
    "Red Rot",
    "Smut",
    "Yellow Leaf",
}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def validate_dataset() -> None:
    missing_splits = [
        split for split in ("train", "val", "test") if not (DATASET_DIR / split).is_dir()
    ]
    if missing_splits:
        raise FileNotFoundError(
            f"Missing dataset split folder(s): {', '.join(missing_splits)}. "
            "Expected dataset\\train, dataset\\val, and dataset\\test."
        )

    for split in ("train", "val", "test"):
        split_dir = DATASET_DIR / split
        class_dirs = {path.name for path in split_dir.iterdir() if path.is_dir()}
        missing_classes = EXPECTED_CLASSES - class_dirs
        unexpected_classes = class_dirs - EXPECTED_CLASSES
        if missing_classes or unexpected_classes:
            details = []
            if missing_classes:
                details.append(f"missing: {', '.join(sorted(missing_classes))}")
            if unexpected_classes:
                details.append(f"unexpected: {', '.join(sorted(unexpected_classes))}")
            raise ValueError(f"Invalid classes in dataset\\{split}: {'; '.join(details)}")

        counts = {}
        for class_name in sorted(EXPECTED_CLASSES):
            count = sum(
                1
                for path in (split_dir / class_name).iterdir()
                if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
            )
            counts[class_name] = count
        empty_classes = [name for name, count in counts.items() if count == 0]
        if empty_classes:
            raise ValueError(
                f"Empty class folder(s) in dataset\\{split}: {', '.join(empty_classes)}"
            )
        print(f"{split}: {sum(counts.values())} images across {len(counts)} classes")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train or evaluate the sugarcane classifier.")
    parser.add_argument("--evaluate", action="store_true", help="Evaluate on the test split.")
    parser.add_argument("--model", help="Model path for evaluation.")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=224)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    validate_dataset()

    if args.evaluate:
        model_path = (
            Path(args.model)
            if args.model
            else next(
                (
                    path
                    for path in (TRAINED_MODEL, LEGACY_TRAINED_MODEL)
                    if path.exists()
                ),
                DEFAULT_MODEL,
            )
        )
        if not model_path.exists():
            raise FileNotFoundError(f"Model does not exist: {model_path}")
        model = YOLO(str(model_path))
        result = model.val(
            data=str(DATASET_DIR),
            split="test",
            project=str(OUTPUT_DIR),
            name="test",
        )
        print(f"Top-1 accuracy: {result.top1:.4f}")
        print(f"Top-5 accuracy: {result.top5:.4f}")
        return

    model = YOLO(str(DEFAULT_MODEL) if DEFAULT_MODEL.exists() else "yolo11n-cls.pt")
    model.train(
        data=str(DATASET_DIR),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        workers=0,
        project=str(OUTPUT_DIR),
        name="sugarcane-classifier",
    )
    print(
        "Training complete. Model: "
        f"{OUTPUT_DIR / 'sugarcane-classifier' / 'weights' / 'best.pt'}"
    )


if __name__ == "__main__":
    main()
