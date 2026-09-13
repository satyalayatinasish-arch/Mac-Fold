# Security Policy

## Supported Versions

Security and stability updates are applied to the latest stable release branch of Mac Fold.

| Version | Supported | Minimum OS |
| ------- | --------- | ---------- |
| 1.0.x   | :white_check_mark: | macOS 14.0+ (Sonoma, Sequoia) |
| < 1.0   | :x: | Legacy / unsupported |

## Privacy and Permissions Guarantees

Mac Fold requires two optional or essential system capabilities:
1. **Screen Recording (`ScreenCaptureKit`)**: Used strictly to mirror the local desktop onto the Metal perspective fold overlay in real time. Frames are captured directly into GPU memory buffers and are never saved to disk, serialized, or transmitted over the network.
2. **Camera Access (`Vision`)**: Used strictly for local, on-device face/eye landmark tracking to calibrate viewer eye elevation. Camera frames are processed strictly in RAM and discarded immediately. No video frames or biometric measurements are ever recorded, cached, or transmitted.

## Reporting a Vulnerability

If you discover a security vulnerability or privacy concern in Mac Fold, please report it privately:

1. Use GitHub [Private Vulnerability Reporting](https://github.com/satyalayatinasish-arch/Mac-Fold/security/advisories/new) on the repository.
2. Or contact the maintainer directly via GitHub profile details.

Please include:
- A description of the vulnerability and its potential impact.
- Steps to reproduce or proof-of-concept code.
- Your macOS version and MacBook hardware model.

You will receive an acknowledgement within 48 hours and updates as a fix is developed and released.
