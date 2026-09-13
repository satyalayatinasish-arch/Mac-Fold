import os
import math
import glob
import hid

class LidAngleSensor:
    def __init__(self):
        self._iio_device_path = self._find_iio_accelerometer()
    
    @property
    def is_available(self) -> bool:
        return True # Best effort availability on Linux
    
    def _find_iio_accelerometer(self) -> str | None:
        devices = glob.glob("/sys/bus/iio/devices/iio:device*")
        for dev in devices:
            if os.path.exists(os.path.join(dev, "in_accel_x_raw")) and \
               os.path.exists(os.path.join(dev, "in_accel_y_raw")) and \
               os.path.exists(os.path.join(dev, "in_accel_z_raw")):
                return dev
        return None

    def _read_iio_accel(self) -> float | None:
        if not self._iio_device_path:
            return None
        try:
            with open(os.path.join(self._iio_device_path, "in_accel_y_raw"), 'r') as f:
                y = float(f.read().strip())
            with open(os.path.join(self._iio_device_path, "in_accel_z_raw"), 'r') as f:
                z = float(f.read().strip())
            
            # Simple gravity vector tilt calculation
            tilt = math.atan2(y, z) * 180 / math.pi
            return tilt
        except Exception:
            return None

    def _read_acpi_lid(self) -> float | None:
        lid_paths = [
            "/proc/acpi/button/lid/LID0/state",
            "/proc/acpi/button/lid/LID/state"
        ]
        for path in lid_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        state = f.read().strip().lower()
                        if "open" in state:
                            return 120.0
                        elif "closed" in state:
                            return 0.0
                except Exception:
                    continue
        return None

    def _read_hid_sensor(self) -> float | None:
        try:
            devices = hid.enumerate()
            for device in devices:
                if device.get('usage_page') == 0x20 and device.get('usage') == 0x8A:
                    h = hid.device()
                    h.open_path(device['path'])
                    # Actual read format depends on specific sensor output
                    # h.read(64)
                    h.close()
                    # Return parsed angle if implemented
                    return None
        except Exception:
            pass
        return None

    def angle(self) -> float | None:
        # 1. Try HID sensor (most accurate, like Apple sensor)
        hid_angle = self._read_hid_sensor()
        if hid_angle is not None:
            return hid_angle
            
        # 2. Try accelerometer tilt (provides analog angle)
        accel_angle = self.base_tilt_from_accelerometer()
        if accel_angle is not None:
            # Assuming vertical lid orientation, accelerometer gives lid angle
            return accel_angle
            
        # 3. Fallback to ACPI binary state (open/closed)
        acpi_angle = self._read_acpi_lid()
        if acpi_angle is not None:
            return acpi_angle
            
        return None
        
    def base_tilt_from_accelerometer(self) -> float | None:
        return self._read_iio_accel()
