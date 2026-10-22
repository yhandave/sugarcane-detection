from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from ultralytics import YOLO

from predict import IMAGE_EXTENSIONS, MODEL_CANDIDATES


PROJECT_ROOT = Path(__file__).resolve().parent


class ClassifierApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Sugarcane Disease Classifier")
        self.root.geometry("760x480")
        self.model: YOLO | None = None

        frame = ttk.Frame(root, padding=16)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(
            frame,
            text="Sugarcane Disease Classifier",
            font=("Segoe UI", 16, "bold"),
        ).pack(anchor=tk.W)
        ttk.Label(
            frame,
            text="Select one or more images to identify the disease.",
        ).pack(anchor=tk.W, pady=(4, 12))

        ttk.Button(
            frame,
            text="Upload Images",
            command=self.select_images,
        ).pack(anchor=tk.W)

        self.output = tk.Text(frame, height=20, width=90, state=tk.DISABLED)
        self.output.pack(fill=tk.BOTH, expand=True, pady=(12, 0))

    def select_images(self) -> None:
        paths = filedialog.askopenfilenames(
            title="Select sugarcane images",
            filetypes=[
                (
                    "Supported images",
                    " ".join(f"*{extension}" for extension in sorted(IMAGE_EXTENSIONS)),
                ),
                ("All files", "*.*"),
            ],
        )
        if paths:
            self.predict_images([Path(path) for path in paths])

    def predict_images(self, paths: list[Path]) -> None:
        model_path = next((path for path in MODEL_CANDIDATES if path.is_file()), None)
        if model_path is None:
            messagebox.showerror(
                "Model not found",
                "Train the model first with:\n\n"
                ".venv\\Scripts\\python.exe train.py",
            )
            return

        try:
            if self.model is None:
                self.model = YOLO(str(model_path))
            results = self.model.predict(
                source=[str(path) for path in paths],
                project=str(PROJECT_ROOT / "runs" / "classify"),
                name="upload-predictions",
                exist_ok=True,
            )
        except (OSError, RuntimeError, ValueError) as error:
            messagebox.showerror("Prediction failed", str(error))
            return

        lines = []
        for result in results:
            if result.probs is not None:
                class_name = result.names[result.probs.top1]
                confidence = float(result.probs.top1conf)
                lines.append(f"{Path(result.path).name}: {class_name} ({confidence:.2%})")

        self.output.configure(state=tk.NORMAL)
        self.output.delete("1.0", tk.END)
        self.output.insert(tk.END, "\n".join(lines))
        self.output.configure(state=tk.DISABLED)


def main() -> None:
    root = tk.Tk()
    ClassifierApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
