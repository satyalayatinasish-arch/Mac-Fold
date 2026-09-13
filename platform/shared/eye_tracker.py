import cv2
import threading
import time
import math
from typing import Optional

class EyeTracker:
    def __init__(self):
        self.is_face_visible: bool = False
        self.estimated_elevation_angle: Optional[float] = None
        self.estimated_base_tilt_angle: Optional[float] = None
        
        self._hinge_angle: float = 90.0
        self._base_tilt_angle: float = 0.0
        
        self._lock = threading.Lock()
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._cap: Optional[cv2.VideoCapture] = None
        
        # Load cascades
        self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        self.eye_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_eye.xml')

    def start(self):
        with self._lock:
            if self._running:
                return
            self._running = True
            
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self):
        with self._lock:
            self._running = False
            
        if self._thread:
            self._thread.join()
            self._thread = None
            
        if self._cap:
            self._cap.release()
            self._cap = None

    def update_lid_geometry(self, hinge_angle: float, base_tilt_angle: float):
        with self._lock:
            self._hinge_angle = hinge_angle
            self._base_tilt_angle = base_tilt_angle

    def _run_loop(self):
        self._cap = cv2.VideoCapture(0)
        
        while True:
            with self._lock:
                if not self._running:
                    break
                hinge_angle = self._hinge_angle
                base_tilt_angle = self._base_tilt_angle
                
            ret, frame = self._cap.read()
            if not ret:
                time.sleep(0.1)
                continue
                
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, 1.3, 5)
            
            face_visible = False
            eye_center_y = None
            
            for (x, y, w, h) in faces:
                face_visible = True
                roi_gray = gray[y:y+h, x:x+w]
                eyes = self.eye_cascade.detectMultiScale(roi_gray)
                if len(eyes) > 0:
                    ex, ey, ew, eh = eyes[0]
                    # Normalized Y coordinate of the eye center relative to frame height
                    eye_abs_y = y + ey + eh / 2.0
                    eye_center_y = eye_abs_y / frame.shape[0]
                    break
            
            with self._lock:
                self.is_face_visible = face_visible
                self.estimated_base_tilt_angle = base_tilt_angle
                
                if eye_center_y is not None:
                    half_field = 55 * math.pi / 360  # vertical camera FOV
                    camera_offset = math.atan(math.tan(half_field) * (eye_center_y - 0.5) * 2) * 180 / math.pi
                    camera_world_elevation = hinge_angle + base_tilt_angle - 90
                    elevation = camera_world_elevation + camera_offset
                    # Clamp between 0 and 60
                    self.estimated_elevation_angle = max(0.0, min(elevation, 60.0))
                else:
                    self.estimated_elevation_angle = None
            
            time.sleep(1.0 / 12.0)
            
    def deinit(self):
        self.stop()
