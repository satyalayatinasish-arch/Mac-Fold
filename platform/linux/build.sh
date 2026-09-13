#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Creating virtual environment..."
python3 -m venv .venv
source .venv/bin/activate

echo "Installing requirements..."
pip install -r requirements.txt
pip install pyinstaller

echo "Building executable with PyInstaller..."
pyinstaller --onefile --windowed --name Mac-Fold-Linux main.py

if command -v appimagetool >/dev/null 2>&1; then
    echo "appimagetool found, creating AppImage is possible."
    # Further AppImage creation steps could go here if needed
fi

echo "Build complete. Binary is in dist/Mac-Fold-Linux"
