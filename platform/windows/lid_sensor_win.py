import struct
import time

try:
    import hid
    HID_AVAILABLE = True
except ImportError:
    HID_AVAILABLE = False

try:
    import winsdk.windows.devices.sensors as sensors
    WINSDK_AVAILABLE = True
except ImportError:
    WINSDK_AVAILABLE = False

class LidAngleSensor:
    def __init__(self):
        self.device = None
        self._find_device()
        self._accelerometer = None
        if WINSDK_AVAILABLE:
            self._accelerometer = sensors.Accelerometer.get_default()

    def _find_device(self):
        if not HID_AVAILABLE:
            return
        
        try:
            for device_dict in hid.enumerate():
                # Look for Apple HID sensor: usage_page=0x20, usage=0x8A
                if device_dict.get('usage_page') == 0x20 and device_dict.get('usage') == 0x8A:
                    self.device = hid.device()
                    self.device.open_path(device_dict['path'])
                    self.device.set_nonblocking(True)
                    return
        except Exception as e:
            print(f"Error finding HID device: {e}")
            self.device = None

    @property
    def is_available(self) -> bool:
        return self.device is not None or self._accelerometer is not None

    def angle(self) -> float | None:
        if self.device:
            try:
                # Same protocol: report 7 = 5 bytes hundredths, report 1 = 3 bytes whole degrees
                report = self.device.get_feature_report(7, 5)
                if report and len(report) >= 5:
                    val = struct.unpack('<i', bytes(report[1:5]))[0]
                    return val / 100.0
                
                report = self.device.get_feature_report(1, 3)
                if report and len(report) >= 3:
                    val = struct.unpack('<h', bytes(report[1:3]))[0]
                    return float(val)
            except Exception:
                pass
        return None
    
    def base_tilt_from_accelerometer(self) -> float | None:
        if self._accelerometer:
            try:
                reading = self._accelerometer.get_current_reading()
                if reading:
                    import math
                    y = reading.acceleration_y
                    z = reading.acceleration_z
                    tilt_rad = math.atan2(y, z)
                    return math.degrees(tilt_rad)
            except Exception:
                pass
        return None
