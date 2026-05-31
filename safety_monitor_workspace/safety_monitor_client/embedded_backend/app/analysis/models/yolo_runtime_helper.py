from __future__ import annotations

from pathlib import Path
from typing import Any

from models.device_helper import resolve_torch_device


def build_yolo_runtime(
    *,
    yolo_cls,
    model_path: str,
    requested_device: str,
    require_cuda: bool,
    prefer_tensorrt_engine: bool,
) -> tuple[Any, str, str, dict[str, Any]]:
    device = resolve_torch_device(
        requested_device=requested_device,
        require_cuda=require_cuda,
    )
    runtime_model_path = resolve_runtime_model_path(
        yolo_cls=yolo_cls,
        model_path=model_path,
        device=device,
        prefer_tensorrt_engine=prefer_tensorrt_engine,
    )
    try:
        model = load_yolo_model(
            yolo_cls=yolo_cls,
            model_path=runtime_model_path,
        )
    except Exception as error:
        fallback_model_path = _fallback_model_path_for_tensorrt_error(
            model_path=model_path,
            runtime_model_path=runtime_model_path,
            error=error,
        )
        if fallback_model_path is None:
            raise
        runtime_model_path = fallback_model_path
        model = load_yolo_model(
            yolo_cls=yolo_cls,
            model_path=runtime_model_path,
        )
    predict_kwargs = build_predict_kwargs(
        runtime_model_path=runtime_model_path,
        device=device,
    )
    return model, runtime_model_path, device, predict_kwargs


def resolve_runtime_model_path(
    *,
    yolo_cls,
    model_path: str,
    device: str,
    prefer_tensorrt_engine: bool,
) -> str:
    resolved_path = Path(model_path)
    if not prefer_tensorrt_engine:
        return str(resolved_path)
    if resolved_path.suffix.lower() == ".engine":
        if not _is_tensorrt_available():
            pt_path = resolved_path.with_suffix(".pt")
            if pt_path.exists():
                return str(pt_path)
        return str(resolved_path)

    engine_path = resolved_path.with_suffix(".engine")
    if engine_path.exists() and _is_tensorrt_available():
        return str(engine_path)

    if _can_export_tensorrt_engine(model_path=resolved_path, device=device):
        try:
            return _export_tensorrt_engine(
                yolo_cls=yolo_cls,
                model_path=resolved_path,
                device=device,
            )
        except Exception as error:
            if not _is_tensorrt_related_error(error):
                raise

    return str(resolved_path)


def build_predict_kwargs(*, runtime_model_path: str, device: str) -> dict[str, Any]:
    runtime_suffix = Path(runtime_model_path).suffix.lower()
    if runtime_suffix == ".engine":
        return {}
    return {"device": device}


def _can_export_tensorrt_engine(*, model_path: Path, device: str) -> bool:
    return model_path.suffix.lower() == ".pt" and device.lower().startswith("cuda")


def _export_tensorrt_engine(*, yolo_cls, model_path: Path, device: str) -> str:
    _patch_tensorrt_for_ultralytics_export()
    export_model = load_yolo_model(
        yolo_cls=yolo_cls,
        model_path=str(model_path),
    )
    exported_path = export_model.export(
        format="engine",
        device=device,
        verbose=False,
    )
    return str(Path(exported_path).resolve())


def load_yolo_model(*, yolo_cls, model_path: str):
    return yolo_cls(model_path, task="detect")


def _patch_tensorrt_for_ultralytics_export() -> None:
    try:
        import tensorrt as trt
    except ImportError:
        return

    if not hasattr(trt.NetworkDefinitionCreationFlag, "EXPLICIT_BATCH"):
        setattr(trt.NetworkDefinitionCreationFlag, "EXPLICIT_BATCH", 0)
    if not hasattr(trt.Builder, "platform_has_fast_fp16"):
        setattr(trt.Builder, "platform_has_fast_fp16", False)
    if not hasattr(trt.Builder, "platform_has_fast_int8"):
        setattr(trt.Builder, "platform_has_fast_int8", False)


def _is_tensorrt_available() -> bool:
    try:
        import tensorrt  # noqa: F401
    except ImportError:
        return False
    return True


def _fallback_model_path_for_tensorrt_error(
    *,
    model_path: str,
    runtime_model_path: str,
    error: Exception,
) -> str | None:
    if Path(runtime_model_path).suffix.lower() != ".engine":
        return None
    if not _is_tensorrt_related_error(error):
        return None

    fallback_path = Path(model_path)
    if fallback_path.exists():
        return str(fallback_path)
    return None


def _is_tensorrt_related_error(error: Exception) -> bool:
    error_text = str(error).lower()
    return "tensorrt" in error_text or isinstance(error, ModuleNotFoundError)
