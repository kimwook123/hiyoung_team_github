from __future__ import annotations

from time import perf_counter

from app.log_utils import log_line


class PipelineProfiler:
    def __init__(
        self,
        *,
        enabled: bool,
        log_interval_frames: int = 120,
        source_label: str = "",
    ) -> None:
        self.enabled = enabled
        self.log_interval_frames = max(1, log_interval_frames)
        self.source_label = source_label
        self.frame_count = 0
        self.stage_totals: dict[str, float] = {}
        self.frame_started_at = 0.0

    def begin_frame(self) -> None:
        if not self.enabled:
            return
        self.frame_started_at = perf_counter()

    def measure(self, stage_name: str, callback):
        if not self.enabled:
            return callback()

        started_at = perf_counter()
        result = callback()
        elapsed = perf_counter() - started_at
        self.stage_totals[stage_name] = self.stage_totals.get(stage_name, 0.0) + elapsed
        return result

    def end_frame(self) -> None:
        if not self.enabled:
            return

        elapsed = perf_counter() - self.frame_started_at
        self.stage_totals["frame_total"] = self.stage_totals.get("frame_total", 0.0) + elapsed
        self.frame_count += 1
        if self.frame_count < self.log_interval_frames:
            return

        averages = {
            stage_name: (total / self.frame_count) * 1000.0
            for stage_name, total in self.stage_totals.items()
        }
        ordered_parts = [
            f"{stage_name}={averages[stage_name]:.1f}ms"
            for stage_name in sorted(averages.keys())
        ]
        source_text = self.source_label or "unknown-source"
        log_line(
            "PERF",
            source=source_text,
            frames=self.frame_count,
            stages=" ".join(ordered_parts),
        )
        self.frame_count = 0
        self.stage_totals.clear()
