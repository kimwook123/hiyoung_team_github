from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parent
ANALYSIS_DIR = (BACKEND_DIR / "app" / "analysis").resolve()
ULTRALYTICS_CONFIG_DIR = (BACKEND_DIR / "data" / "ultralytics").resolve()
ULTRALYTICS_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("YOLO_CONFIG_DIR", str(ULTRALYTICS_CONFIG_DIR))
if str(ANALYSIS_DIR) not in sys.path:
    sys.path.insert(0, str(ANALYSIS_DIR))

from app.config import (  # noqa: E402
    ANALYSIS_DEVICE,
    ANALYSIS_REQUIRE_CUDA,
    MODEL_PATH,
    PREFER_TENSORRT_ENGINE,
)
from app.analysis.models.device_helper import resolve_torch_device  # noqa: E402
from app.analysis.models.yolo_runtime_helper import resolve_runtime_model_path  # noqa: E402


def _has_module(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def main() -> int:
    import torch
    from ultralytics import YOLO

    device = resolve_torch_device(
        requested_device=ANALYSIS_DEVICE,
        require_cuda=ANALYSIS_REQUIRE_CUDA,
    )
    runtime_model_path = Path(
        resolve_runtime_model_path(
            yolo_cls=YOLO,
            model_path=str(MODEL_PATH),
            device=device,
            prefer_tensorrt_engine=PREFER_TENSORRT_ENGINE,
        )
    ).resolve()
    engine_path = MODEL_PATH.with_suffix(".engine").resolve()

    print(f"model_path={MODEL_PATH}")
    print(f"runtime_model_path={runtime_model_path}")
    print(f"engine_path={engine_path}")
    print(f"cuda_available={torch.cuda.is_available()}")
    print(f"analysis_device={device}")
    print(f"tensorrt_available={_has_module('tensorrt')}")
    print(f"onnx_available={_has_module('onnx')}")
    print(f"onnxslim_available={_has_module('onnxslim')}")
    print(f"onnxruntime_available={_has_module('onnxruntime')}")
    print(f"yolo_config_dir={ULTRALYTICS_CONFIG_DIR}")

    if not runtime_model_path.exists():
        print("ERROR: runtime model path does not exist.")
        return 1

    if not device.lower().startswith("cuda"):
        print("ERROR: analysis device is not CUDA.")
        return 1

    if PREFER_TENSORRT_ENGINE and runtime_model_path.suffix.lower() != ".engine":
        print("ERROR: TensorRT engine was requested, but runtime did not resolve to a .engine file.")
        return 1

    if runtime_model_path.suffix.lower() == ".engine" and not engine_path.exists():
        print("ERROR: runtime resolved to .engine but the engine file was not found on disk.")
        return 1

    print("runtime_engine_ready=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
