import sys, os, math, threading, time, configparser
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageDraw, ImageTk
import pystray
import mss
import cv2
import numpy as np

# Mocking shared module imports as they probably don't exist yet in the repo
class DepthGeometry: pass
class DepthTuning: pass
class EyeTracker: pass

from lid_sensor_linux import LidAngleSensor

CONFIG_PATH = os.path.expanduser('~/.macfold_linux.ini')

class HingeCanvas(tk.Canvas):
    def __init__(self, parent, **kwargs):
        super().__init__(parent, **kwargs)
        self.config(bg='black', highlightthickness=0)
        self.angle = 90
        
    def update_angle(self, angle):
        self.angle = angle
        self.delete("all")
        # Draw placeholder hinge visualization
        self.create_text(50, 50, text=f"Lid Angle: {self.angle:.1f}°", fill="white")

class PopoverWindow(tk.Toplevel):
    def __init__(self, parent, app):
        super().__init__(parent)
        self.app = app
        self.overrideredirect(True)
        self.configure(bg='black')
        
        # Check Wayland
        if os.environ.get('XDG_SESSION_TYPE') == 'wayland':
            print("Warning: Running on Wayland. Overlay support may be limited.")
            self.attributes('-type', 'dialog') # Adjust for Wayland
        else:
            self.attributes('-type', 'dock')
            
        self.geometry("300x400")
        
        ttk.Label(self, text="Mac Fold Linux", foreground="white", background="black").pack(pady=10)
        self.hinge_canvas = HingeCanvas(self, width=100, height=100)
        self.hinge_canvas.pack(pady=10)
        
        ttk.Button(self, text="Close", command=self.withdraw).pack(pady=10)
        self.withdraw()

class FoldOverlay(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.overrideredirect(True)
        self.attributes('-topmost', True)
        self.configure(bg='black')
        
        if os.environ.get('XDG_SESSION_TYPE') != 'wayland':
            self.attributes('-type', 'dock')
            
        # Transparency setup for Linux
        self.wait_visibility(self)
        try:
            self.attributes('-alpha', 0.8)
        except tk.TclError:
            pass
            
        self.canvas = tk.Canvas(self, bg='black', highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)
        self.withdraw()

class MacFoldApp:
    def __init__(self, root):
        self.root = root
        self.root.withdraw()
        
        self.sensor = LidAngleSensor()
        self.popover = PopoverWindow(root, self)
        self.overlay = FoldOverlay(root)
        
        self.config = configparser.ConfigParser()
        if os.path.exists(CONFIG_PATH):
            self.config.read(CONFIG_PATH)
            
        self.running = True
        self.thread = threading.Thread(target=self.update_loop, daemon=True)
        self.thread.start()
        
        self.setup_tray()
        
    def setup_tray(self):
        # Create a simple icon
        image = Image.new('RGB', (64, 64), color='black')
        draw = ImageDraw.Draw(image)
        draw.rectangle([16, 16, 48, 48], fill='white')
        
        menu = pystray.Menu(
            pystray.MenuItem('Show Controls', self.show_popover),
            pystray.MenuItem('Quit', self.quit_app)
        )
        self.tray_icon = pystray.Icon("MacFold", image, "Mac Fold", menu)
        
        # Run tray icon in a separate thread because pystray blocks
        threading.Thread(target=self.tray_icon.run, daemon=True).start()

    def show_popover(self):
        self.popover.deiconify()
        
    def quit_app(self):
        self.running = False
        self.tray_icon.stop()
        self.root.quit()

    def update_loop(self):
        while self.running:
            angle = self.sensor.angle()
            if angle is not None:
                # Update hinge canvas in main thread
                self.root.after(0, self.popover.hinge_canvas.update_angle, angle)
                
                # Logic to show/hide overlay based on angle < 90
                if angle < 90:
                    self.root.after(0, self.overlay.deiconify)
                    self.root.after(0, self.overlay.geometry, f"{self.root.winfo_screenwidth()}x{self.root.winfo_screenheight()}+0+0")
                else:
                    self.root.after(0, self.overlay.withdraw)
            time.sleep(0.1)

def main():
    root = tk.Tk()
    app = MacFoldApp(root)
    root.mainloop()

if __name__ == '__main__':
    main()
