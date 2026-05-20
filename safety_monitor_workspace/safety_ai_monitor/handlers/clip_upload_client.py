from pathlib import Path

import requests

# 이 파일은 로컬 mp4 클립을 FastAPI 서버에 업로드하는 작은 HTTP 클라이언트입니다.
# multipart/form-data는 파일 업로드에 사용하는 HTTP 요청 형식입니다.

class ClipUploadClient:
    # 이벤트 종료 후 생성된 clip_path 파일을 POST /api/clips로 보냅니다.
    def __init__(
        self,
        upload_url: str,
        timeout_seconds: float = 5.0,
    ) -> None:
        self.upload_url = upload_url
        self.timeout_seconds = timeout_seconds

    def upload_clip(
        self,
        clip_path: str,
        event_key: str | None = None,
        source_key: str | None = None,
        source_slug: str | None = None,
    ) -> dict | None:
        # 서버가 꺼져 있거나 응답이 잘못 와도 앱이 죽지 않게 None으로 실패를 돌려줍니다.
        normalized_path = clip_path.strip()
        if not normalized_path or normalized_path == "-":
            return None

        file_path = Path(normalized_path)
        if not file_path.exists() or not file_path.is_file():
            return None
        if file_path.suffix.lower() != ".mp4":
            return None

        data = {}
        if event_key:
            data["event_key"] = event_key
        if source_key:
            data["source_key"] = source_key
        if source_slug:
            data["source_slug"] = source_slug

        try:
            with file_path.open("rb") as clip_file:
                response = requests.post(
                    self.upload_url,
                    files={"file": (file_path.name, clip_file, "video/mp4")},
                    data=data,
                    timeout=self.timeout_seconds,
                )
            if 200 <= response.status_code < 300:
                result = response.json()
                if isinstance(result, dict):
                    return result
            print(f"HTTP clip upload failed: status_code={response.status_code}")
        except requests.RequestException as error:
            print(f"HTTP clip upload failed: {error}")
        except ValueError as error:
            print(f"HTTP clip upload response parse failed: {error}")

        return None
