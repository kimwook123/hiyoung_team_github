import sys
import requests
import threading
import queue
import re
from PyQt5 import QtWidgets, QtGui, QtCore

SERVER = 'http://127.0.0.1:8080'


class MJPEGStreamReader(QtCore.QThread):
    frame_ready = QtCore.pyqtSignal(QtGui.QPixmap)

    def __init__(self, client_id):
        super().__init__()
        self.client_id = client_id
        self.running = True
        self.frame_queue = queue.Queue(maxsize=6)
        self.dropped_frames = 0

    def run(self):
        try:
            url = f"{SERVER}/stream/{self.client_id}"
            r = requests.get(url, stream=True, timeout=10)
            if r.status_code != 200:
                self.frame_ready.emit(QtGui.QPixmap())
                return

            boundary = b'--frame'
            buffer = b''

            for chunk in r.iter_content(chunk_size=8192):
                if not self.running:
                    break
                buffer += chunk

                while True:
                    idx = buffer.find(boundary)
                    if idx == -1:
                        break

                    if idx > 0:
                        frame_data = buffer[:idx]
                        # extract JPEG data (after \r\n\r\n)
                        sep = frame_data.find(b'\r\n\r\n')
                        if sep != -1:
                            jpeg_data = frame_data[sep+4:]
                            if jpeg_data:
                                img = QtGui.QImage.fromData(jpeg_data)
                                if not img.isNull():
                                    scaled_img = img.scaled(640, 
                                                            360, 
                                                            QtCore.Qt.KeepAspectRatio,
                                                            QtCore.Qt.SmoothTransformation)
                                    try:
                                        self.frame_queue.put_nowait(scaled_img)
                                    except queue.Full:
                                        self.dropped_frames += 1  # count drops

                    buffer = buffer[idx + len(boundary):]

        except Exception as e:
            print(f"Stream error for {self.client_id}: {e}")
        finally:
            self.running = False

    def stop(self):
        self.running = False
        self.wait()


class StreamWidget(QtWidgets.QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(640, 360)
        self.setStyleSheet('background: black; color: white; font-size: 14px;')
        self.setAlignment(QtCore.Qt.AlignCenter)
        self.client_id = None
        self.stream_thread = None
        self.display_timer = QtCore.QTimer(self)
        self.display_timer.timeout.connect(self.display_frame)

    def start(self, client_id):
        if self.client_id == client_id:
            return
        self.stop()

        self.client_id = client_id
        self.stream_thread = MJPEGStreamReader(client_id)
        self.stream_thread.finished.connect(self.on_stream_finished)
        self.stream_thread.start()
        self.display_timer.start(30)  # 30ms = ~33fps max
        self.setText(f'Connecting to {client_id}...')

    def stop(self):
        if self.stream_thread:
            self.stream_thread.stop()
            self.stream_thread = None
        self.display_timer.stop()
        self.client_id = None
        self.setText('Idle')

    def display_frame(self):
        if not self.stream_thread:
            return
        try:
            # 큐에서 이미 스케일링된 QImage를 꺼내서 표시
            scaled_img = self.stream_thread.frame_queue.get_nowait()
            # UI 스레드에서 가볍게 QPixmap으로 변환만 해서 표시
            self.setPixmap(QtGui.QPixmap.fromImage(scaled_img))

            if self.stream_thread.dropped_frames > 0:
                print(f"[{self.client_id}] Dropped frames: {self.stream_thread.dropped_frames}")
        except queue.Empty:
            pass
        except Exception:
            pass

    def on_stream_finished(self):
        self.setText('Stream ended')


class Viewer(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('TCP-IP Viewer - Real-time')
        self.setGeometry(100, 100, 1300, 750)
        layout = QtWidgets.QGridLayout(self)
        self.widgets = [StreamWidget(self) for _ in range(4)]
        positions = [(0, 0), (0, 1), (1, 0), (1, 1)]
        for w, pos in zip(self.widgets, positions):
            layout.addWidget(w, *pos)

        self.client_list = []
        self.refresh_timer = QtCore.QTimer(self)
        self.refresh_timer.timeout.connect(self.refresh_clients)
        self.refresh_timer.start(3000)  # check every 3s
        self.refresh_clients()

    def refresh_clients(self):
        try:
            r = requests.get(f"{SERVER}/clients", timeout=1)
            if r.status_code == 200:
                clients = r.json()
                # update widgets
                for i in range(4):
                    if i < len(clients):
                        self.widgets[i].start(clients[i])
                    else:
                        self.widgets[i].stop()
        except Exception as e:
            print(f"Refresh error: {e}")

    def closeEvent(self, event):
        for w in self.widgets:
            w.stop()
        event.accept()


if __name__ == '__main__':
    app = QtWidgets.QApplication(sys.argv)
    v = Viewer()
    v.show()
    sys.exit(app.exec_())
