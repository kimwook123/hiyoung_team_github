# 실행 가이드

## 1. 의존성 준비

```powershell
install_dependencies.bat all
```

가상환경은 워크스페이스 루트의 `.venv/`에 생성됩니다.

서버만 준비:

```powershell
install_dependencies.bat server
```

클라이언트 포함 전체 런타임 준비:

```powershell
install_dependencies.bat client
```

## 2. 서버 실행

```powershell
run_server.bat
```

기본 주소:

```text
http://127.0.0.1:8000
```

서버 역할:

- 클라이언트 소스/상태/프리뷰/탐지 결과 저장
- 클라이언트별 `rule_config` 기준 이벤트 판정
- 이벤트 구간 서버 직접 클립 인코딩
- 이벤트와 클립 조회 API 제공
- 뷰어용 실시간 프리뷰 스트림 제공
- 뷰어에서 전송한 룰 설정 저장

## 3. 클라이언트 실행

```powershell
run_client.bat
```

클라이언트 역할:

- PC당 1개만 실행
- 로컬 `0`번 카메라 1개만 사용
- 객체 탐지 실행
- 서버로 프리뷰/상태/프레임 탐지 결과 전송

내장 백엔드 기본 주소:

```text
http://127.0.0.1:8100
```

## 4. 뷰어 실행

```powershell
run_viewer.bat
```

뷰어 역할:

- 연결된 클라이언트의 실시간 프리뷰 표시
- 오프라인 클라이언트 숨김
- 서버 이벤트/클립 조회
- 클라이언트별 위험상황 룰 설정 변경

## 5. 빌드

클라이언트:

```powershell
build_client.bat
```

뷰어:

```powershell
build_viewer.bat
```
