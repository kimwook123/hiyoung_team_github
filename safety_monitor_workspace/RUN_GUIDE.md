# 실행 가이드

이 프로젝트는 `서버 -> 뷰어 -> 클라이언트` 순서로 실행하는 것을 권장합니다.

## 0. 경로 정책

Flutter Windows 빌드는 경로가 길면 실패하기 쉽습니다. 저장소는 Desktop, OneDrive, Downloads 아래가 아니라 C 또는 D 드라이브 루트 근처의 짧은 실제 경로에 둡니다.

권장 예시:

```text
C:\safety_monitor_workspace
D:\safety_monitor_workspace
C:\hiyoung_team_github\safety_monitor_workspace
```

빌드 배치파일은 Windows 경로 길이 문제를 줄이기 위해 `C:\smw_build_client`, `C:\smw_build_viewer` 같은 짧은 junction 경로를 임시로 만든 뒤 Flutter Windows 빌드를 실행합니다. 그래도 저장소 자체는 C 또는 D 드라이브 루트 근처의 짧은 실제 경로에 두는 것을 권장합니다.

## 1. 환경 확인과 의존성 준비

```bat
check_environment.bat
install_dependencies.bat all
```

가상환경은 워크스페이스 루트의 `.venv/`에 생성됩니다.

서버만 준비:

```bat
install_dependencies.bat server
```

클라이언트 내장 백엔드까지 준비:

```bat
install_dependencies.bat client
```

## 2. 서버 실행

```bat
run_server.bat
```

기본 주소:

```text
http://127.0.0.1:8000
```

다른 PC에서는 `127.0.0.1`이 아니라 서버 PC의 IPv4 주소를 사용합니다.

예:

```text
http://192.168.24.114:8000
```

다른 PC 브라우저에서 아래 주소가 열려야 원격 클라이언트/뷰어 연결이 가능합니다.

```text
http://<서버IP>:8000/health
```

열리지 않으면 서버 PC에서 관리자 권한으로 실행합니다.

```bat
setup_server_firewall.bat
```

서버 역할:

- 클라이언트 소스/상태/프리뷰/탐지 결과 저장
- `sources.payload_json.rule_config` 기준 이벤트 판정
- 이벤트 DB 저장
- 이벤트 클립 MP4와 썸네일 JPG 생성
- 뷰어용 실시간 프리뷰 스트림 제공
- 이벤트/클립/썸네일/룰 설정 API 제공

## 3. 뷰어 실행

```bat
run_viewer.bat
```

뷰어에서 서버 URL을 입력하고 적용합니다.

뷰어 주요 기능:

- 좌측 카메라 리스트에서 카메라 선택/선택 해제
- 가운데 Live Monitoring에서 최대 4개 영상 그리드 표시
- 영상 클릭 시 선택, 선택된 영상을 다시 클릭하면 선택 해제
- 선택된 카메라가 없으면 전체 이벤트 로그 표시
- 선택된 카메라가 있으면 해당 카메라 이벤트만 표시
- 이벤트 로그 자체 스크롤 영역 제공
- 이벤트 로그에 클립 썸네일 표시
- 이벤트 클릭 시 해당 카메라 타일에서 이벤트 클립 재생
- 클립 재생 중 영상 우상단 닫기 버튼으로 라이브/기존 상태 복귀
- 위험구역 이벤트 클립 재생 시 해당 이벤트의 ROI 사각형 오버레이
- 우측 하단 룰 설정 패널에서 안전모/위험구역 룰 설정
- 좌상단 `DB Clear` 테스트 버튼으로 서버 이벤트 DB/클립/썸네일 초기화

## 4. 클라이언트 실행

```bat
run_client.bat
```

클라이언트 역할:

- PC당 1개 실행
- 로컬 `0`번 카메라 1개 사용
- 객체 탐지 실행
- 서버로 소스 등록, 상태 heartbeat, 프리뷰 프레임, 프레임 탐지 결과 전송

내장 백엔드 기본 주소:

```text
http://127.0.0.1:8100
```

`run_client.bat` 실행 시 원격 서버 URL을 입력합니다. 원격 PC에서 실행할 때는 서버 PC의 IPv4 주소를 입력합니다.


### Windows 빌드 경로 오류 대응

`media_kit_libs_windows_video_ANGLE_EXTRACT.lastbuildstate` 또는 `media_kit_libs_windows_video_LIBMPV_EXTRACT.lastbuildstate` 관련 `MSB3491` 오류는 대부분 코드 문제가 아니라 MSBuild 중간 산출물 경로가 너무 길거나 이전 빌드 산출물이 꼬인 경우입니다.

대응 순서:

```bat
build_client.bat
build_viewer.bat
```

배치파일은 자동으로 `C:\smw_build_client`, `C:\smw_build_viewer` junction을 임시 생성해서 짧은 경로로 빌드합니다. 정상 성공/실패 경로에서는 junction을 즉시 해제하고, `Ctrl+C`나 터미널 강제 종료로 남아도 다음 빌드 실행 시작 시 기존 junction을 먼저 정리합니다. 실패가 계속되면 `safety_monitor_client\build` 또는 `safety_monitor_viewer\build` 폴더를 삭제한 뒤 다시 실행합니다.

## 5. 빌드

클라이언트:

```bat
build_client.bat
```

뷰어:

```bat
build_viewer.bat
```

빌드 배치파일은 `flutter clean`, Windows Flutter 생성 파일 복구, `flutter pub get`, Windows 빌드를 순서대로 수행합니다.

`run_client.bat`, `run_viewer.bat`는 실행 파일이 없거나 소스보다 오래된 경우 자동으로 빌드를 먼저 시도합니다.

## 6. 위험구역 ROI 편집 흐름

1. 뷰어에서 카메라를 선택합니다.
2. `위험구역 드래그 편집`을 누릅니다.
3. 기존 ROI가 있으면 영상 위에 표시됩니다.
4. 영상 위에서 새 ROI를 드래그합니다.
5. 드래그 중/드래그 직후에는 화면에만 임시 ROI가 반영됩니다.
6. `위험구역 편집 종료`를 누르면 서버에 저장됩니다.
7. ROI 저장만으로 위험구역 룰이 자동 ON 되지는 않습니다.
8. 위험구역 룰 토글 ON/OFF는 이벤트 판정 적용 여부만 제어합니다.
9. 현재 위험구역 룰은 임시 기준으로 `helmet` 또는 `no_helmet` 계열 탐지 박스가 ROI와 겹치면 이벤트로 판정합니다.

## 7. 테스트용 DB Clear

뷰어 좌상단 `DB Clear`는 테스트용입니다.

삭제 대상:

- 서버 이벤트 DB 레코드
- 프레임 탐지 DB 레코드
- 서버 이벤트 클립 MP4
- 이벤트 썸네일 JPG
- 서버 메모리상의 진행 중 이벤트 상태

나중에 운영 UI에서는 숨기거나 제거할 수 있습니다.
