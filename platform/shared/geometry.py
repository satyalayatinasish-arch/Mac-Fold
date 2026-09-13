import math
from dataclasses import dataclass

@dataclass
class DepthTuning:
    viewing_distance: float = 2.7
    recession: float = 2.0
    observer_elevation: float = 20.0
    base_tilt: float = 0.0
    blur_evenness: float = 0.4
    dim_reach: float = 0.7
    max_blur_radius: float = 55.0
    max_dim: float = 0.4

class DepthGeometry:
    def __init__(self, max_separation_degrees: float = 88.0):
        self.max_separation_degrees = max_separation_degrees

    def corners(
        self,
        start_angle: float,
        current_angle: float,
        viewing_distance_ratio: float,
        recession: float,
        observer_elevation: float,
        base_tilt: float,
        screen_size: tuple[float, float]
    ) -> list[tuple[float, float]]:
        width = float(screen_size[0])
        height = float(screen_size[1])
        start = (start_angle + base_tilt) * math.pi / 180
        current = (current_angle + base_tilt) * math.pi / 180
        eye_elevation = observer_elevation * math.pi / 180
        travel = max(start_angle - current_angle, 0.0)
        view_scale = min(
            max(1 + 0.55 * math.sin(eye_elevation) + 0.25 * math.sin(abs(base_tilt) * math.pi / 180), 0.5),
            1.75
        )
        separation = min(recession * travel * view_scale, self.max_separation_degrees) * math.pi / 180
        eye_distance = height * viewing_distance_ratio
        start_centre_y = height / 2 * math.sin(start)
        start_centre_z = -height / 2 * math.cos(start)
        eye_y = start_centre_y + eye_distance * math.sin(eye_elevation)
        eye_z = start_centre_z + eye_distance * math.cos(eye_elevation)
        along = eye_y * math.sin(current) - eye_z * math.cos(current)
        depth = max(eye_y * math.cos(current) + eye_z * math.sin(current), height / 10)
        half = width / 2

        def project(x: float, y: float) -> tuple[float, float]:
            scale = depth / (depth + y * math.sin(separation))
            return (
                half + (x - half) * scale,
                along + (y * math.cos(separation) - along) * scale
            )

        return [project(0, 0), project(width, 0), project(width, height), project(0, height)]
