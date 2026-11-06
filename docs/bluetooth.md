# Bluetooth

When a Bluetooth device connects or disconnects, Crocus shows a short event (2 s) and then returns to what the island showed before.

## In the island

- Left: the device's symbol, from its Bluetooth device class (and the name for Apple and Beats):

| Device | Symbol |
|---|---|
| AirPods / Pro / Max, Beats | `airpods`, `airpodspro`, `airpodsmax`, `beats.headphones` |
| Headphones, headsets | `headphones` |
| Speakers / car audio | `hifispeaker` / `car` |
| Mouse, Magic Mouse, trackpad | `computermouse`, `magicmouse`, `rectangle.and.hand.point.up.left` |
| Keyboard / game controller | `keyboard` / `gamecontroller` |
| iPhone, iPad, Mac, Watch, printer | `iphone`, `ipad`, `laptopcomputer`, `applewatch`, `printer` |
| Anything else | `dot.radiowaves.left.and.right` |

- Right: **Connected** in green, **Disconnected** in grey.
- VoiceOver reads the device name, e.g. "AirPods von Bilal connected".
- No battery level: there is no public API for the battery of AirPods and other headphones.

## Which devices

- **All devices** – headphones and speakers as well as mice, keyboards, trackpads, controllers and phones.
- Devices already connected when Crocus starts don't show an event; neither does anything in the first 5 s after the Mac wakes (devices reconnect on their own).
- A disconnect only shows for a device Crocus saw connected.

## Permission

macOS asks before an app may use Bluetooth. Crocus never asks on its own: use the menu bar, **Allow Bluetooth…** (until the onboarding asks for it). Denied, the events are off and the menu shows **Allow in System Settings…** (Privacy & Security → Bluetooth).

Entitlement: `com.apple.security.device.bluetooth`; `NSBluetoothAlwaysUsageDescription` in Info.plist.

## How it works

- **Classic Bluetooth** (AirPods, most headphones): IOBluetooth notifications for connects (any device) and disconnects (per connected device). IOBluetooth sometimes delivers them on a background thread (CoreBluetooth's queue), so the handlers read the device there and continue on the main thread.
- **Bluetooth Low Energy** mice, keyboards and trackpads (e.g. Logitech MX Master 3S): IOBluetooth doesn't report them (or only some, without a device class – those are skipped there), and CoreBluetooth's connection events are not available on macOS. They appear in the I/O Registry as HID devices with transport "Bluetooth Low Energy"; Crocus gets a notification when one appears or goes and reads only its properties (name, usage, vendor). It never opens the device or reads input, so no Input Monitoring permission is needed. One physical device often has several HID interfaces that appear one after another (a keyboard first as media keys, then as keyboard): Crocus groups them by vendor, product and name, waits 0.5 s for all of them and reports the device once, with the most telling kind (mouse, keyboard, controller).
- No polling in either case.
