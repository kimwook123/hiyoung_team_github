from datetime import datetime

import cv2

from core.detection_model import DetectionModel
from core.event_clip_recorder import EventClipRecorder
from core.event_filter import EventFilter
from core.event_handler import EventHandler
from core.event_rule import EventRule
from core.frame_detection_recorder import FrameDetectionRecorder
from core.frame_source import FrameSource
from core.object_tracker import PersonTracker

# 이 파일은 실제 프레임 처리 루프를 담당합니다.
# 프레임을 읽고, DetectionResult를 만들고, EventRule/EventFilter/EventHandler 흐름을 순서대로 실행합니다.

class VideoPipeline:
    # 하나의 입력 소스를 끝까지 분석하는 실행 단위입니다.
    # Python AI Worker의 핵심 루프가 이 클래스 안에 있습니다.
    def __init__(
        self,
        frame_source: FrameSource,
        model: DetectionModel,
        rules: list[EventRule],
        handlers: list[EventHandler],
        event_filter: EventFilter,
        tracker: PersonTracker,
        clip_recorder: EventClipRecorder,
        frame_detection_recorder: FrameDetectionRecorder,
        show_screen: bool,
        restart_checker=None,
        source_type: str = "",
        source_value: str = "",
        source_key: str = "",
        source_slug: str = "",
        client_id: str = "",
        session_id: str = "",
    ) -> None:
        self.frame_source = frame_source
        self.model = model
        self.rules = rules
        self.handlers = handlers
        self.event_filter = event_filter
        self.tracker = tracker
        self.clip_recorder = clip_recorder
        self.frame_detection_recorder = frame_detection_recorder
        self.show_screen = show_screen
        self.screen_available = show_screen
        self.source_time_mode = "real"
        self.restart_checker = restart_checker
        self.source_type = source_type
        self.source_value = source_value
        self.source_key = source_key
        self.source_slug = source_slug
        self.client_id = client_id
        self.session_id = session_id

    def run(self) -> str:
        # 이 함수가 실제 분석 루프입니다.
        # 매 프레임마다 모델 추론 -> 이벤트 판정 -> 상태 관리 -> 로그/클립 저장이 이어집니다.
        frame_id = 0
        stop_reason = "completed"

        self.frame_source.open()
        self.model.load()
        if self.frame_source.__class__.__name__ == "VideoFileFrameSource":
            self.source_time_mode = "video"

        try:
            while True:
                if self._should_restart():
                    stop_reason = "source_changed"
                    break

                ok, frame = self.frame_source.read()
                if not ok:
                    break
                now = datetime.now()

                # 모델 결과를 공통 형식으로 변환한다
                result = self.model.predict(frame, frame_id)
                self._fill_result_time(result=result, now=now, frame_id=frame_id)
                result = self.tracker.update(result)
                self.frame_detection_recorder.write(
                    result,
                    source_type=self.source_type,
                    source_value=self.source_value,
                    source_key=self.source_key,
                    source_slug=self.source_slug,
                    frame_width=frame.shape[1],
                    frame_height=frame.shape[0],
                )

                events = []
                for rule in self.rules:
                    # DetectionResult를 Event 후보로 바꾸는 단계입니다.
                    events.extend(rule.check(result))

                state_events = self.event_filter.update(
                    events=events,
                )
                active_events = self.event_filter.get_active_events(
                    frame_id=frame_id,
                    now=now,
                )
                self._attach_source_context(state_events)
                self._attach_source_context(active_events)
                # 클립 저장은 EventFilter가 만든 상태 이벤트를 기준으로 시작/종료됩니다.
                self.clip_recorder.update(
                    frame=frame,
                    frame_id=frame_id,
                    active_events=active_events,
                    state_events=state_events,
                )
                for event in state_events:
                    for handler in self.handlers:
                        # EventHandler는 txt 로그, JSONL, HTTP 전송 같은 후처리를 담당합니다.
                        handler.handle(event)

                # 진행 중인 ACTIVE 이벤트도 파일 기반 GUI가 현재 프레임 박스를 갱신할 수 있게
                # txt 로그와 로컬 JSONL에는 계속 반영합니다.
                for event in active_events:
                    for handler in self.handlers:
                        if handler.__class__.__name__ in {
                            "LogEventHandler",
                            "JsonEventHandler",
                            "HttpEventHandler",
                        }:
                            handler.handle(event)

                if self.screen_available:
                    display_frame = self._make_display_frame(
                        frame=frame,
                        result=result,
                        events=active_events,
                    )
                    if not self._show_frame(display_frame):
                        self.screen_available = False
                    elif cv2.waitKey(1) & 0xFF == ord("q"):
                        break

                frame_id += 1
        finally:
            closed_events = self.event_filter.close_all()
            self._attach_source_context(closed_events)
            self.clip_recorder.finalize(closed_events)
            for event in closed_events:
                for handler in self.handlers:
                    handler.handle(event)
            self.frame_source.release()
            self._close_screen()

        return stop_reason

    def _should_restart(self) -> bool:
        if self.restart_checker is None:
            return False

        try:
            return bool(self.restart_checker())
        except Exception:
            return False

    def _show_frame(self, frame) -> bool:
        try:
            cv2.imshow("Safety AI Monitor", frame)
            return True
        except cv2.error as error:
            # OpenCV GUI 기능이 없는 환경에서는 화면 표시만 끄고 계속 진행한다
            print(f"[WARN] OpenCV 화면 표시를 사용할 수 없습니다: {error}")
            return False

    def _close_screen(self) -> None:
        if not self.screen_available:
            return

        try:
            cv2.destroyAllWindows()
        except cv2.error as error:
            # destroyAllWindows가 지원되지 않는 OpenCV 빌드도 있다
            print(f"[WARN] OpenCV 창 정리를 건너뜁니다: {error}")

    def _make_display_frame(self, frame, result, events):
        # 원본 프레임을 복사해서 박스와 이벤트 정보를 그린다
        display_frame = frame.copy()

        for detection in result.detections:
            x1 = detection.box.x1
            y1 = detection.box.y1
            x2 = detection.box.x2
            y2 = detection.box.y2

            cv2.rectangle(display_frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            label = f"{detection.name} {detection.score:.2f}"
            if detection.track_id is not None:
                label += f" id={detection.track_id}"
            cv2.putText(
                display_frame,
                label,
                (x1, max(20, y1 - 8)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 0),
                2,
            )

        event_y = 30
        for event in events:
            person_text = ""
            if event.person_id is not None:
                person_text = f" person={event.person_id}"
            event_text = (
                f"{event.level.value} {event.message}"
                f"{person_text} {event.duration_seconds:.1f}s"
            )
            cv2.putText(
                display_frame,
                event_text,
                (10, event_y),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (0, 0, 255),
                2,
            )
            event_y += 30

        return display_frame

    def _fill_result_time(self, result, now: datetime, frame_id: int) -> None:
        # 영상 파일은 영상 재생 시간 기준, 스트림/카메라는 현재 시각 기준으로 시간 정보를 채웁니다.
        source_seconds = self.frame_source.get_time_seconds()
        if self.source_time_mode == "video":
            if source_seconds is None:
                source_seconds = frame_id / max(1.0, self.frame_source.get_fps())
            result.source_time_seconds = source_seconds
            result.source_time_text = self._format_video_time(source_seconds)
            result.event_created_at = datetime.fromtimestamp(source_seconds)
            return

        result.source_time_seconds = 0.0 if source_seconds is None else source_seconds
        result.source_time_text = now.isoformat(timespec="seconds")
        result.event_created_at = now

    def _format_video_time(self, seconds_value: float) -> str:
        total_ms = max(0, int(seconds_value * 1000))
        minutes = (total_ms // 60000) % 60
        seconds = (total_ms // 1000) % 60
        milliseconds = total_ms % 1000
        hours = total_ms // 3600000
        if hours > 0:
            return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{milliseconds:03d}"
        return f"{minutes:02d}:{seconds:02d}.{milliseconds:03d}"

    def _attach_source_context(self, events: list[object]) -> None:
        for event in events:
            setattr(event, "source_type", self.source_type)
            setattr(event, "source_value", self.source_value)
            setattr(event, "source_key", self.source_key)
            setattr(event, "source_slug", self.source_slug)
            setattr(event, "client_id", self.client_id)
            setattr(event, "session_id", self.session_id)
