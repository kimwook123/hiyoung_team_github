from collections import deque
from dataclasses import dataclass
from pathlib import Path

import cv2

from core.event_rule import Event
from core.event_types import EventStatus


@dataclass
class ClipFrame:
    frame_id: int
    frame: object


@dataclass
class ClipState:
    writer: object
    clip_path: str
    last_frame_id: int


class EventClipRecorder:
    def __init__(
        self,
        enabled: bool,
        clip_dir: str,
        fps: float,
        before_seconds: float,
    ) -> None:
        self.enabled = enabled
        self.clip_dir = Path(clip_dir)
        self.fps = fps if fps > 0 else 30.0
        self.before_seconds = max(0.0, before_seconds)
        self.before_frame_count = max(1, int(self.fps * self.before_seconds))
        self.frame_buffer: deque[ClipFrame] = deque(maxlen=self.before_frame_count)
        self.clip_states: dict[str, ClipState] = {}

    def update(
        self,
        frame,
        frame_id: int,
        active_events: list[Event],
        state_events: list[Event],
    ) -> None:
        if not self.enabled:
            return

        self.frame_buffer.append(ClipFrame(frame_id=frame_id, frame=frame.copy()))

        for event in state_events:
            if event.status == EventStatus.START:
                self._start_clip(event=event, frame=frame, frame_id=frame_id)

        for event in active_events:
            self._write_active_frame(event=event, frame=frame, frame_id=frame_id)

        for event in state_events:
            if event.status == EventStatus.END:
                self._finish_clip(event)

    def finalize(self, events: list[Event]) -> None:
        if not self.enabled:
            return

        for event in events:
            self._finish_clip(event)

    def _start_clip(self, event: Event, frame, frame_id: int) -> None:
        if event.event_key in self.clip_states:
            return

        height, width = frame.shape[:2]
        self.clip_dir.mkdir(parents=True, exist_ok=True)
        clip_name = f"{event.event_type.value}_{event.person_id or 'x'}_{event.started_frame_id}.mp4"
        clip_path = str((self.clip_dir / clip_name).resolve())
        writer = cv2.VideoWriter(
            clip_path,
            cv2.VideoWriter_fourcc(*"mp4v"),
            self.fps,
            (width, height),
        )
        if not writer.isOpened():
            return

        clip_state = ClipState(
            writer=writer,
            clip_path=clip_path,
            last_frame_id=-1,
        )
        self.clip_states[event.event_key] = clip_state

        for clip_frame in self.frame_buffer:
            if clip_frame.frame_id < (event.started_frame_id or 0):
                writer.write(clip_frame.frame)
                clip_state.last_frame_id = clip_frame.frame_id

        writer.write(frame)
        clip_state.last_frame_id = frame_id

    def _write_active_frame(self, event: Event, frame, frame_id: int) -> None:
        clip_state = self.clip_states.get(event.event_key)
        if clip_state is None:
            return
        if frame_id <= clip_state.last_frame_id:
            return

        clip_state.writer.write(frame)
        clip_state.last_frame_id = frame_id

    def _finish_clip(self, event: Event) -> None:
        clip_state = self.clip_states.pop(event.event_key, None)
        if clip_state is None:
            return

        clip_state.writer.release()
        event.clip_path = clip_state.clip_path
