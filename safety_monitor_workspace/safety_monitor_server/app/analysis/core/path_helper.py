from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE_ROOT = PROJECT_ROOT.parent


def to_abs_path(path_text: str) -> str:
    # 상대 경로를 프로젝트 기준 절대 경로로 바꾼다
    path = Path(path_text)
    if path.is_absolute():
        return str(path)

    project_path = (PROJECT_ROOT / path).resolve()
    if project_path.exists():
        return str(project_path)

    workspace_path = (WORKSPACE_ROOT / path).resolve()
    return str(workspace_path)


def to_project_path(path_text: str) -> str:
    # 내부 설정 파일과 로그는 항상 프로젝트 폴더 기준으로 쓴다
    path = Path(path_text)
    if path.is_absolute():
        return str(path)

    return str((PROJECT_ROOT / path).resolve())
