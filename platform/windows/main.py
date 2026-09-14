import sys, os, math, threading, time, configparser
from pathlib import Path

# Add parent to path for shared imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageDraw, ImageTk
import pystray
import mss
import cv2
import numpy as np

try:
    from shared.geometry import DepthGeometry, DepthTuning
    from shared.eye_tracker import EyeTracker
except ImportError:
    # Dummy classes for standalone testing if shared is not available
    class DepthGeometry: pass
    class DepthTuning: pass
    class EyeTracker: pass

from lid_sensor_win import LidAngleSensor

class Preferences:
    def __init__(self):
        self.config_file = Path.home() / '.macfold_windows.ini'
        self.config = configparser.ConfigParser()
        self.load()

    def load(self):
        self.config.read(self.config_file)
        if 'Preferences' not in self.config:
            self.config['Preferences'] = {}
        
        prefs = self.config['Preferences']
        self.enabled = prefs.getboolean('enabled', True)
        self.live_picture = prefs.getboolean('live_picture', True)
        self.observer_elevation_angle = prefs.getfloat('observer_elevation_angle', 10.0)
        self.base_tilt_angle = prefs.getfloat('base_tilt_angle', 15.0)
        self.viewing_distance = prefs.getfloat('viewing_distance', 50.0)
        self.camera_tracking = prefs.getboolean('camera_tracking', False)
        self.fold_threshold = prefs.getfloat('fold_threshold', 90.0)

    def save(self):
        prefs = self.config['Preferences']
        prefs['enabled'] = str(self.enabled)
        prefs['live_picture'] = str(self.live_picture)
        prefs['observer_elevation_angle'] = str(self.observer_elevation_angle)
        prefs['base_tilt_angle'] = str(self.base_tilt_angle)
        prefs['viewing_distance'] = str(self.viewing_distance)
        prefs['camera_tracking'] = str(self.camera_tracking)
        prefs['fold_threshold'] = str(self.fold_threshold)
        
        with open(self.config_file, 'w') as f:
            self.config.write(f)

class FoldOverlay:
    def __init__(self, root):
        self.window = tk.Toplevel(root)
        self.window.withdraw()
        self.window.overrideredirect(True)
        self.window.attributes('-topmost', True)
        self.window.attributes('-transparentcolor', 'black')
        
        self.canvas = tk.Canvas(self.window, bg='black', highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)
        
        self.sct = mss.mss()
        self.active = False
        self.geometry = None

    def update_frame(self):
        if not self.active:
            return
            
        monitor = self.sct.monitors[1] # Primary monitor
        sct_img = self.sct.grab(monitor)
        img = np.array(sct_img)
        
        # In a real implementation, apply warpPerspective using DepthGeometry
        # Here we just show the transparent layer as placeholder for warping
        
        self.window.after(33, self.update_frame) # ~30fps

    def show(self):
        if not self.active:
            self.window.deiconify()
            self.window.state('zoomed') # fullscreen on windows
            self.active = True
            self.update_frame()

    def hide(self):
        if self.active:
            self.window.withdraw()
            self.active = False

class HingeCanvas(tk.Canvas):
    def __init__(self, parent, width=250, height=145, **kwargs):
        super().__init__(parent, width=width, height=height, bg='#2d2d2d', highlightthickness=0, **kwargs)
        self.width = width
        self.height = height
        self.angle = 90.0
        self.base_tilt = 15.0
        self.draw()

    def draw(self):
        self.delete("all")
        cx, cy = self.width / 2, self.height / 2 + 30
        
        base_len = 80
        lid_len = 80
        
        # Base
        base_angle_rad = math.radians(self.base_tilt)
        bx = cx - base_len * math.cos(base_angle_rad)
        by = cy + base_len * math.sin(base_angle_rad)
        self.create_line(cx, cy, bx, by, fill='gray', width=6, capstyle=tk.ROUND)
        
        # Lid
        lid_angle_rad = math.radians(self.angle + self.base_tilt)
        lx = cx + lid_len * math.cos(lid_angle_rad)
        ly = cy - lid_len * math.sin(lid_angle_rad)
        self.create_line(cx, cy, lx, ly, fill='#aaaaaa', width=4, capstyle=tk.ROUND)
        
        # Screen line
        self.create_line(cx, cy, lx, ly, fill='cyan', width=2, capstyle=tk.ROUND)
        
        # Hinge joint
        self.create_oval(cx-4, cy-4, cx+4, cy+4, fill='silver', outline='gray')

    def set_angle(self, angle, base_tilt):
        self.angle = angle
        self.base_tilt = base_tilt
        self.draw()

class PopoverWindow:
    def __init__(self, root, app):
        self.window = tk.Toplevel(root)
        self.window.withdraw()
        self.window.overrideredirect(True)
        self.window.configure(bg='#2d2d2d')
        self.app = app
        
        # Title
        tk.Label(self.window, text="Mac Fold v1.0.8", bg='#2d2d2d', fg='white', font=('Arial', 12, 'bold')).pack(pady=5)
        
        # Canvas
        self.canvas = HingeCanvas(self.window)
        self.canvas.pack(pady=5)
        
        # Toggles
        self.fold_var = tk.BooleanVar(value=app.prefs.enabled)
        tk.Checkbutton(self.window, text="Fold Effect", variable=self.fold_var, command=self.update_prefs, bg='#2d2d2d', fg='white', selectcolor='#444').pack(anchor='w', padx=10)
        
        # Settings/Quit
        btn_frame = tk.Frame(self.window, bg='#2d2d2d')
        btn_frame.pack(fill='x', pady=10)
        tk.Button(btn_frame, text="Quit", command=app.quit, bg='#444', fg='white').pack(side='right', padx=10)
        tk.Button(btn_frame, text="Hide", command=self.hide, bg='#444', fg='white').pack(side='right')
        
    def update_prefs(self):
        self.app.prefs.enabled = self.fold_var.get()
        self.app.prefs.save()

    def show(self):
        # Position near bottom right (rough tray area)
        x = self.window.winfo_screenwidth() - 300
        y = self.window.winfo_screenheight() - 400
        self.window.geometry(f"250x300+{x}+{y}")
        self.window.deiconify()
        self.window.lift()

    def hide(self):
        self.window.withdraw()

class MacFoldApp:
    def __init__(self, root):
        self.root = root
        self.prefs = Preferences()
        self.sensor = LidAngleSensor()
        
        self.overlay = FoldOverlay(root)
        self.popover = PopoverWindow(root, self)
        
        self.running = True
        
        self.setup_tray()
        self.start_threads()

    def setup_tray(self):
        img = Image.new('RGB', (64, 64), color='black')
        d = ImageDraw.Draw(img)
        d.rectangle((16, 16, 48, 48), fill='cyan')
        
        menu = pystray.Menu(
            pystray.MenuItem('Show Settings', self.show_popover),
            pystray.MenuItem('Quit', self.quit)
        )
        self.icon = pystray.Icon("MacFold", img, "Mac Fold", menu)
        threading.Thread(target=self.icon.run, daemon=True).start()

    def show_popover(self):
        self.root.after(0, self.popover.show)

    def start_threads(self):
        threading.Thread(target=self.sensor_loop, daemon=True).start()

    def sensor_loop(self):
        while self.running:
            angle = self.sensor.angle()
            if angle is None:
                angle = 120.0 # dummy value if sensor not working
                
            base_tilt = self.prefs.base_tilt_angle
            
            # Update canvas
            self.root.after(0, self.popover.canvas.set_angle, angle, base_tilt)
            
            if self.prefs.enabled and angle < self.prefs.fold_threshold:
                self.root.after(0, self.overlay.show)
            else:
                self.root.after(0, self.overlay.hide)
                
            time.sleep(0.1)

    def quit(self):
        self.running = False
        self.icon.stop()
        self.root.quit()

def main():
    root = tk.Tk()
    root.withdraw()
    app = MacFoldApp(root)
    root.mainloop()

if __name__ == '__main__':
    main()
