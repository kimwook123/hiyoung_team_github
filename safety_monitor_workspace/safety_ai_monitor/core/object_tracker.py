from dataclasses import dataclass

from core.detection_model import Detection, DetectionResult


@dataclass
class TrackState:
    center_x: int
    center_y: int
    missed_frames: int


class PersonTracker:
    def __init__(self, max_distance: int = 100, max_missing_frames: int = 30) -> None:
        self.max_distance = max(1, max_distance)
        self.max_missing_frames = max(1, max_missing_frames)
        self.next_track_id = 1
        self.tracks: dict[int, TrackState] = {}

    def update(self, result: DetectionResult) -> DetectionResult:
        # person 객체에만 간단한 ID를 붙인다
        person_detections = [detection for detection in result.detections if detection.name == "person"]
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
