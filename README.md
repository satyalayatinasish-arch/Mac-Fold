# Mac Fold

Mac Fold is a macOS lid-angle-driven display-fold project. The production app source is in [`work/Mac-Fold`](work/Mac-Fold).

The app uses ScreenCaptureKit and Metal to render a live desktop overlay only while a compatible MacBook lid is below 90°. It ends the overlay at 90° while opening.

## Build

```sh
cd work/Mac-Fold
./build.sh --run
```

Grant Screen Recording permission when prompted. The project uses an undocumented internal HID lid-angle interface, so it is for local experimentation and can break after macOS updates.

The original iPhone Duo prototype remains under [`Sources/iPhoneDuo`](Sources/iPhoneDuo) for reference; it is not the production Mac Fold app.
