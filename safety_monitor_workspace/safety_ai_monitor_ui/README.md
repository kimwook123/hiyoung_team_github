# Safety AI Monitor UI

Flutter로 만든 영상 모니터링 UI입니다.

이 앱은 Python 분석 파이프라인과 분리되어 동작하며, 현재는 서버 조회 중심 구조를 사용합니다.

## 현재 역할

- 영상 파일 열기
- 스트림 등록
- 유튜브 링크 입력 후 자동 변환 재생
- 멀티소스 탭 관리
- 현재 활성 소스 재생
- 비활성 소스 자동 일시정지
- 서버 이벤트 목록/상세 조회
- 현재 재생 시간 기준 객체 탐지 박스 오버레이
- 이벤트 시작 시점 이동
- 이벤트 클립 재생과 원본 복귀

## 현재 구조

### GUI -> Python

- `source_state.json`
- `sources_state.json`

GUI는 Python에게 “무엇을 분석할지”만 전달합니다.

### GUI -> Server

- 이벤트 목록/상세
- 프레임 탐지 현재 시점
- 소스 상태
- 서버 클립 재생 URL
- health

GUI는 더 이상 로컬 `events.jsonl`, `frame_detections.jsonl`, `ui_bridge.json`을 주 소비 경로로 사용하지 않습니다.

## 멀티소스 UX

- 여러 영상/스트림을 등록할 수 있습니다.
- 상단 소스 칩으로 화면을 전환합니다.
- 현재 선택된 소스만 화면에 재생됩니다.
- 다른 소스는 백그라운드 분석은 계속되지만, GUI 플레이어는 자동으로 pause됩니다.
- `선택 해제`는 소스를 삭제하는 것이 아니라 전체 로그 보기 상태로 전환합니다.
- 소스 제거는 별도 닫기 동작으로 수행합니다.

## 이벤트/클립 UX

- 이벤트 목록 클릭:
  - 해당 이벤트의 원본 시작 시점으로 이동
- 이벤트 상세의 `클립 열기`:
  - 이벤트 start~end 클립 재생
- 클립 재생 중:
  - 원본 복귀 버튼 제공
  - 원본 시간축 기준 객체 탐지 박스 유지

## 객체 탐지 박스 표시 방식

- 현재 재생 시간에서 `source_time_seconds`를 계산합니다.
- 서버의 `/api/frame-detections/current`를 조회합니다.
- 그 시점과 가장 가까운 프레임 탐지 스냅샷을 받아 박스를 오버레이합니다.
- 따라서 이벤트 자체가 아니라 “프레임별 전체 탐지 결과”를 기준으로 박스를 표시합니다.

## 주요 파일

- `lib/screens/home_screen.dart`
  - 전체 UX 조립
- `lib/controllers/video_panel_controller.dart`
  - 재생 상태, replay 복귀, pause 제어
- `lib/services/event_api_service.dart`
  - 서버 HTTP 조회
- `lib/widgets/video_view_box.dart`
  - 영상 및 오버레이 UI
- `lib/widgets/file_bar.dart`
  - 상단 소스 추가/전환 UI

## 서버 연동

기본 서버 주소:

- `http://127.0.0.1:8000`

주요 조회 API:

- `/health`
- `/api/events`
- `/api/events/detail`
- `/api/frame-detections/current`
- `/api/source-status`
- `/api/clips/{clip_name}`

## 참고 패키지

- `media_kit`, `media_kit_video`, `media_kit_libs_video`
- `file_selector`
- `http`
