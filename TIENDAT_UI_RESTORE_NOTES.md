# Tiến Đạt 3-tab UI restoration

Restores the legacy Tiến Đạt Home / Features / Settings presentation in `ThreeOneOSSix/ContentView.swift`, while retaining the 3106 app entry point and project configuration. The existing 3106 `SettingsView` source remains in place under its own name.

The legacy AIM/MOD list is connected to the current 3106 patch library and `DevicePatchService` apply/restore entry points. The three original background images were already in the 3106 asset catalog and match the old source by SHA-256.

**Build status:** not compiled in this environment. Open the Xcode project and build for a device/simulator before signing or installing. Verify patch package availability and behavior on-device.
