from abc import ABC, abstractmethod

from core.event_rule import Event


class EventHandler(ABC):
    # 콘솔 출력, 로그 저장, 알람 전송 등은 이 구조를 따라 확장한다

    @abstractmethod
    def handle(self, event: Event) -> None:
        pass
