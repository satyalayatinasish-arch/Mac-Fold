# -*- mode: python ; coding: utf-8 -*-
import cv2
import os

cv2_path = os.path.dirname(cv2.__file__)
haarcascade_path1 = os.path.join(cv2_path, 'data', 'haarcascade_frontalface_default.xml')
haarcascade_path2 = os.path.join(cv2_path, 'data', 'haarcascade_eye.xml')

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        (haarcascade_path1, 'cv2/data'),
        (haarcascade_path2, 'cv2/data')
    ],
    hiddenimports=['shared', 'shared.geometry', 'shared.eye_tracker'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='Mac-Fold-Windows',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,
)
