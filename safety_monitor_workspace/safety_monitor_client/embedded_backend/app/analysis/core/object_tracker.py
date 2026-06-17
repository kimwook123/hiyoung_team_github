# 분석 파이프라인 안에서 사용하는 object_tracker 기능을 분리한 파일입니다.
# pipeline.py에서 조립되는 분석 부품 중 하나입니다.

from dataclasses import dataclass

from core.detection_model import Detection, DetectionResult

# 이 파일은 person 객체에만 간단한 추적 ID를 붙입니다.
# 현재 프로젝트는 사람별 event_key를 만들 때 이 track_id를 사용합니다.

@dataclass
class TrackState:
    # 이전 프레임에서 본 사람 위치를 기억해 같은 사람인지 추정합니다.
    center_x: int
    center_y: int
    missed_frames: int


class PersonTracker:
    # 매우 단순한 거리 기반 추적기입니다.
    # 고급 추적기라기보다 "같은 person을 잠깐 이어 보는 용도"에 가깝습니다.
    def __init__(self, max_distance: int = 100, max_missing_frames: int = 30) -> None:
        self.max_distance = max(1, max_distance)
        self.max_missing_frames = max(1, max_missing_frames)
        self.next_track_id = 1
        self.tracks: dict[int, TrackState] = {}

    def update(self, result: DetectionResult) -> DetectionResult:
        # person 객체에만 추적 ID를 붙여 이후 EventFilter와 로그가 사람별로 동작하게 합니다.
        person_detections = [
            detection
            for detection in result.detections
            if detection.name.strip().lower() == "person"
        ]
        if not person_detections:
            self._increase_missed_frames()
            self._remove_lost_tracks()
            return result

        unmatched_track_ids = set(self.tracks.keys())
        for detection in person_detections:
            center_x, center_y = detection.box.center()
            matched_track_id = self._find_best_track(
                center_x=center_x,
                center_y=center_y,
                candidate_track_ids=unmatched_track_ids,
            )

            if matched_track_id is None:
                matched_track_id = self.next_track_id
                self.next_track_id += 1

            detection.track_id = matched_track_id
            self.tracks[matched_track_id] = TrackState(
                center_x=center_x,
                center_y=center_y,
                missed_frames=0,
            )
            unmatched_track_ids.discard(matched_track_id)

        for track_id in unmatched_track_ids:
            self.tracks[track_id].missed_frames += 1

        self._remove_lost_tracks()
        return result

    def _find_best_track(
        self,
        center_x: int,
        center_y: int,
        candidate_track_ids: set[int],
    ) -> int | None:
        # 가장 가까운 기존 track을 골라 같은 사람으로 이어 붙입니다.
        best_track_id = None
        best_distance = None

        for track_id in candidate_track_ids:
            track = self.tracks[track_id]
            distance = abs(track.center_x - center_x) + abs(track.center_y - center_y)
            if distance > self.max_distance:
                continue

            if best_distance is None or distance < best_distance:
                best_distance = distance
                best_track_id = track_id

        return best_track_id

    def _increase_missed_frames(self) -> None:
        for track in self.tracks.values():
            track.missed_frames += 1

    def _remove_lost_tracks(self) -> None:
        lost_track_ids = [
            track_id
            for track_id, track in self.tracks.items()
            if track.missed_frames > self.max_missing_frames
        ]
        for track_id in lost_track_ids:
            del self.tracks[track_id]
