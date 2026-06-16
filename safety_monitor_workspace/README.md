# Safety Monitor Workspace

이 저장소는 `클라이언트 -> 서버 -> 뷰어` 구조로 동작하는 CCTV 기반 안전 모니터링 시스템입니다.

현재 정책은 단순합니다.

- PC 1대당 클라이언트 1개만 실행합니다.
- 클라이언트 1개는 CCTV/카메라 1개만 사용합니다.
- 카메라 입력은 `0`번 인덱스로 고정합니다.
- 클라이언트는 객체 탐지를 수행하고, 서버는 클라이언트별 룰 설정을 기준으로 위험 이벤트를 판정/저장합니다.
- 뷰어는 서버를 통해 실시간 화면, 이벤트, 클립, 룰 설정을 관리합니다.

## 프로젝트 구성

### 클라이언트

경로: `safety_monitor_client/`

클라이언트는 각 현장 PC에서 실행되는 프로그램입니다.

역할:

- 로컬 PC의 `0`번 카메라를 엽니다.
- 카메라 프레임에 대해 객체 탐지를 실행합니다.
- 서버로 아래 데이터를 전송합니다.
  - 클라이언트/소스 메타데이터
  - 실행 상태 heartbeat
  - 최신 프리뷰 프레임
  - 프레임별 객체 탐지 결과
- 최초 실행 시 TensorRT `.engine` 파일이 없으면 생성합니다.

클라이언트 식별:

- 클라이언트는 `client_settings.json`의 `client_id`를 우선 사용합니다.
- `client_id`가 없으면 PC hostname 기반으로 `client_<hostname>` 형태의 식별자를 생성합니다.
- 같은 PC에서 클라이언트를 껐다 켜도 같은 `client_id`를 유지하는 것을 목표로 합니다.
- 소스 키에는 클라이언트 식별자가 포함되어, 여러 PC가 모두 `camera 0`을 사용해도 서버에서 서로 다른 소스로 구분됩니다.

참고:

- 현재 클라이언트 GUI는 최소 상태 화면만 남겨 두었습니다.
- 최종 제출 구조에서는 서버처럼 GUI 없이 백그라운드 프로세스로 실행하는 방향을 고려하고 있습니다.
- 백엔드 실행 및 TensorRT 준비 로직은 `EmbeddedBackendService`로 분리되어 있어 headless 전환 시 재사용하기 쉽습니다.

### 서버

경로: `safety_monitor_server/`

서버는 중앙 저장소이자 중계 허브입니다.

역할:

- 클라이언트가 보낸 소스 정보, 상태, 프리뷰, 프레임 탐지 결과를 저장합니다.
- 서버 DB에 저장된 클라이언트별 `rule_config`를 기준으로 위험상황 이벤트를 판정합니다.
- 클라이언트 프리뷰 프레임을 짧게 버퍼링하고, 이벤트가 종료되면 서버가 직접 MP4 클립을 인코딩합니다.
- 이벤트 정보를 DB에 저장하고 뷰어가 조회할 수 있게 제공합니다.
- 최신 프리뷰 프레임을 뷰어용 실시간 스트림 형태로 제공합니다.
- 뷰어에서 변경한 클라이언트별 룰 설정을 저장합니다.
- 프리뷰/탐지/상태 heartbeat처럼 많이 들어오는 요청은 일정 시간 단위로 묶어 요약 로그로 출력합니다.

현재 구현 메모:

- 위험 이벤트 판정은 서버의 `server_event_processor`가 프레임 탐지 결과와 `rule_config`를 보고 수행합니다.
- 이벤트 클립 파일은 서버의 `server_clip_recorder`가 수신 프리뷰 프레임 버퍼를 기반으로 직접 생성합니다.

### 뷰어

경로: `safety_monitor_viewer/`

뷰어는 관제 PC에서 실행되는 모니터링 프로그램입니다.

역할:

- 서버에서 각 클라이언트의 최신 실시간 프리뷰 스트림을 받아 표시합니다.
- 연결이 끊긴 클라이언트는 화면에 표시하지 않습니다.
- 좌측 카메라 리스트와 중앙 Live Monitoring 그리드로 여러 클라이언트를 모니터링합니다.
- 각 클라이언트의 이벤트 목록, 썸네일, 클립 정보를 서버에 요청해 조회합니다.
- 이벤트 클릭 시 해당 카메라 타일에서 클립을 재생합니다.
- 위험구역 이벤트 클립에는 이벤트 당시 ROI 사각형을 오버레이합니다.
- 각 클라이언트별 위험상황 룰 적용 설정을 서버로 전송합니다.
- 테스트용 DB Clear 버튼으로 서버 이벤트 DB/클립/썸네일을 초기화할 수 있습니다.

뷰어에서 설정 가능한 룰:

- 안전모 미착용 룰 ON/OFF
- 위험구역 룰 ON/OFF
- 위험구역 ROI 드래그 편집/편집 종료 시 저장/초기화
- 위험구역 룰 임시 기준: `helmet`, `hardhat`, `no_helmet`, `nohelmet`, `without_helmet`, `no helmet` 탐지 박스가 ROI와 겹치면 `DANGER_ZONE`으로 판정


## 뷰어 UI 정책

- 좌측 `카메라` 패널은 서버에 등록된 클라이언트 카메라를 순서대로 보여줍니다.
- 카메라 항목 또는 영상 타일을 클릭하면 해당 카메라가 선택됩니다.
- 이미 선택된 카메라를 다시 클릭하면 선택이 해제되고 전체 이벤트 로그 보기로 돌아갑니다.
- 이벤트 로그는 우측 전용 스크롤 영역 안에서만 스크롤됩니다.
- 이벤트 로그에는 발생시간, 클라이언트, 탐지 룰, 썸네일을 간단히 표시합니다.
- 이벤트를 클릭하면 이벤트 상세 패널을 띄우는 대신 해당 카메라 타일에서 이벤트 클립을 재생합니다.
- 클립 재생 중 영상 우상단 닫기 버튼으로 클립을 닫습니다.
- 위험구역 ROI는 드래그 즉시 서버 저장하지 않고, `위험구역 편집 종료`를 눌렀을 때 저장합니다.
- ROI 저장은 위험구역 룰 토글을 자동 ON 하지 않습니다.

## 카메라 이름 정책 제안

현재 내부 식별자는 안정성을 위해 `source_key`를 계속 사용합니다. `source_key`는 클라이언트/소스 소유권을 구분하는 기술 키이며, 사용자가 보는 이름으로 쓰기에는 적합하지 않습니다.

권장 정책:

- 내부 키: `source_key`
- 사용자 표시명: `camera_slot_id` 또는 별도 `display_name`
- 기본 표시명: 서버/뷰어 등록 순서 기준 `카메라 1`, `카메라 2`, `카메라 3` ...
- 향후 수동 별칭: 뷰어에서 `입구`, `작업대`, `천장 카메라` 같은 이름으로 변경 가능
- 향후 재매핑: PC가 바뀌어도 사용자가 새 클라이언트 소스를 기존 카메라 슬롯에 연결할 수 있게 확장

단기 구현은 자동 순번 표시가 가장 단순합니다. 장기적으로는 `클라이언트 ID = 카메라 이름`으로 보지 말고, `물리 카메라 위치/슬롯`과 `현재 연결된 클라이언트`를 분리하는 편이 안전합니다.

## 데이터 흐름

1. 각 PC에서 클라이언트 1개가 실행됩니다.
2. 클라이언트는 로컬 `0`번 카메라를 하나의 소스로 등록합니다.
3. 클라이언트는 카메라 프레임 객체 탐지를 수행합니다.
4. 클라이언트는 서버로 프리뷰 프레임, 탐지 결과, 상태 정보를 전송합니다.
5. 서버는 소스별 `rule_config`를 기준으로 위험 이벤트를 판정하고 DB에 저장합니다.
6. 서버는 수신 프리뷰 프레임 버퍼에서 이벤트 구간을 잘라 MP4 클립과 이벤트 썸네일을 직접 생성합니다.
7. 서버는 뷰어에 실시간 프리뷰 스트림과 이벤트/클립 조회 API를 제공합니다.
8. 뷰어는 서버에서 각 클라이언트의 화면과 이벤트 정보를 조회합니다.
9. 뷰어에서 룰 설정을 변경하면 서버 DB의 해당 클라이언트 `rule_config`가 갱신됩니다.

## 경로 정책

이 프로젝트는 Flutter Windows 빌드 산출물 경로가 길어지기 쉽습니다. 다른 PC에서 `git pull` 후 배치파일만으로 안정적으로 빌드/실행하려면 저장소를 사용자 Desktop, OneDrive, Downloads, 문서 폴더 아래가 아니라 C 또는 D 드라이브 루트 근처의 짧은 실제 경로에 두세요.

권장 예시:

```text
C:\safety_monitor_workspace
D:\safety_monitor_workspace
C:\hiyoung_team_github\safety_monitor_workspace
```

비권장 예시:

```text
C:\Users\사용자\Desktop\...\safety_monitor_workspace
C:\Users\사용자\OneDrive\...\safety_monitor_workspace
```

현재 배치파일은 `subst` 가상 드라이브나 junction 우회를 사용하지 않습니다. 경로가 너무 길면 실행 초기에 중단하고 짧은 경로로 옮기라는 메시지를 출력합니다.
## 실행 순서

### 1. 의존성 준비

```powershell
install_dependencies.bat all
```

다른 PC에서 처음 실행하거나 빌드 환경이 의심될 때는 아래 진단 배치로 Python/Flutter/Visual Studio C++/Windows SDK/긴 경로 설정을 먼저 확인할 수 있습니다.

```powershell
check_environment.bat
```

모드별 실행도 가능합니다.

```powershell
install_dependencies.bat server
install_dependencies.bat client
```

기본 가상환경 위치:

```text
.venv/
```

### 2. 서버 실행

```powershell
run_server.bat
```

기본 주소:

```text
http://127.0.0.1:8000
```

다른 PC의 클라이언트/뷰어는 `127.0.0.1`이 아니라 서버 PC의 IPv4 주소를 입력해야 합니다. 서버 실행창에 표시되는 `http://<서버IP>:8000` 주소를 사용하세요. 다른 PC 브라우저에서 `http://<서버IP>:8000/health`가 열리지 않으면 서버 PC에서 관리자 권한으로 아래 파일을 실행해 TCP 8000 방화벽을 허용합니다.

```powershell
setup_server_firewall.bat
```

### 3. 클라이언트 실행

```powershell
run_client.bat
```

클라이언트 내장 백엔드 기본 주소:

```text
http://127.0.0.1:8100
```

클라이언트 GUI의 `Remote server URL`은 실행 중 변경해도 내장 백엔드에 즉시 적용됩니다. 변경 직후 클라이언트는 기존 카메라 소스와 상태를 새 서버로 다시 동기화합니다.

카메라 0번이 실행 시점에 아직 연결되어 있지 않아도 클라이언트는 카메라 소스를 등록하고 주기적으로 실행 상태를 보장합니다. 카메라를 나중에 연결하면 백엔드가 계속 재시도하다가 입력이 열리는 시점부터 탐지를 시작합니다.

### 4. 뷰어 실행

```powershell
run_viewer.bat
```

뷰어 GUI의 `Server URL`도 실행 중 변경할 수 있습니다. 주소를 적용하면 이전 서버에서 가져온 소스/이벤트 화면 상태를 비우고 새 서버에 다시 연결합니다.

## 빌드

클라이언트:

```powershell
build_client.bat
```

뷰어:

```powershell
build_viewer.bat
```

빌드 배치파일은 실행 전 `flutter clean`으로 이전 PC 경로가 남은 CMake 캐시를 정리합니다. 또한 `windows/flutter/CMakeLists.txt` 같은 Windows Flutter 생성 파일이 누락된 경우 `flutter create --platforms=windows .`로 자동 복구한 뒤 빌드합니다.

현재 빌드 배치파일은 임시 드라이브 매핑이나 junction을 사용하지 않고, 현재 워크스페이스 실제 경로에서 바로 빌드합니다. 따라서 저장소 위치를 C/D 루트 근처의 짧은 경로로 유지하는 것이 전제입니다.

`run_client.bat`, `run_viewer.bat`는 실행 파일이 없거나 Flutter 소스보다 오래된 경우 자동으로 각각 `build_client.bat`, `build_viewer.bat`를 먼저 실행합니다.

다른 PC에서 처음 받을 때 권장 순서:

```powershell
check_environment.bat
install_dependencies.bat all
build_client.bat
build_viewer.bat
```

운영 실행만 할 때는 필요한 파일 하나만 실행하면 됩니다.

```powershell
run_server.bat
run_client.bat
run_viewer.bat
```

## 주요 파일

- 루트 전체 의존성: `requirements.txt`
- 서버 전용 의존성: `requirements-server.txt`
- 의존성 설치 배치: `install_dependencies.bat`
- 환경 진단 배치: `check_environment.bat`
- 서버 실행: `run_server.bat`
- 클라이언트 실행: `run_client.bat`
- 뷰어 실행: `run_viewer.bat`
- DB 구조 문서: `DB_SCHEMA.md`
- 실행 가이드: `RUN_GUIDE.md`

## 운영 원칙

- 클라이언트는 영상 소스 소유자입니다.
- 객체 탐지는 클라이언트 PC에서 수행합니다.
- 이벤트 판정, 이벤트 DB 저장, 이벤트 클립 인코딩 기준은 서버입니다.
- 룰 설정은 뷰어에서 변경하고 서버에 저장합니다.
- 뷰어는 서버 API만 사용하며, 클라이언트에 직접 접속하지 않습니다.
- 오프라인 클라이언트는 뷰어 화면에서 숨깁니다.
