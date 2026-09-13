# iPhone Duo

A native macOS prototype for a two-iPhone opening animation.

## Run

Open Terminal in this folder and run:

```sh
swift run
```

The app attempts to read the internal lid angle at 30Hz. If it can access the sensor, that value drives the phones live; otherwise it falls back to the slider, vertical drag, and left/right arrows. You need full Xcode installed (not Command Line Tools alone) to build a SwiftUI macOS app.

## Sensor reality

There is no supported macOS API that supplies a continuous MacBook lid/hinge angle to an ordinary app. This project uses the undocumented HID feature-report technique from LidAngleSensor by Sam Gold (Apache-2.0; attribution in `NOTICE`). Closing a laptop lid still forces system sleep, so the animation cannot visibly react through the closed position.

This is an unsigned local experiment, not a reliable product or an App Store candidate. Apple can change or restrict this internal hardware interface in any macOS update.
