# DedTube on tvOS

This document tells you how to build and run DedTube on the Apple TV simulator and on an Apple TV device. DedTube is the tvOS build of TizenTube Cobalt.

## Requirements

- macOS with Xcode 16 or later and the tvOS SDK.
- depot_tools on your PATH.
- A checkout of this repository in a directory with the name `src`. The DEPS hooks use the path `src/`. gclient does not accept a symbolic link for this directory.

## Set up the checkout

Create the `.gclient` file in the parent directory of the checkout.

```
solutions = [
  {
    "name": "src",
    "url": "https://github.com/reisxd/TizenTubeCobalt.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {},
  },
]
target_os = ["ios"]
```

Download the dependencies and the toolchain:

```
gclient sync --no-history -D
```

## Build for the simulator

```
cd src
cobalt/build/gn.py -p tvos-arm64-simulator -C devel --no-rbe
autoninja -C out/tvos-arm64-simulator_devel cobalt
```

The app bundle is `out/tvos-arm64-simulator_devel/DedTube.app`.

## Run on the simulator

If `xcrun simctl list runtimes` shows no tvOS runtime, install it:

```
xcodebuild -downloadPlatform tvOS
```

List the available simulators and start one:

```
xcrun simctl list devices tvOS
xcrun simctl boot "Apple TV 4K (3rd generation)"
open -a Simulator
```

Install and start the app:

```
xcrun simctl install booted out/tvos-arm64-simulator_devel/DedTube.app
xcrun simctl launch --console booted com.deividfortuna.dedtube
```

Remote DevTools listens on port 9222 inside the simulator. Open `http://localhost:9222` on the Mac to inspect the page.

## Build for a device

A device build needs a code signing identity and a provisioning profile.

The app needs the Extended Virtual Addressing capability. PartitionAlloc reserves large address space pools when the app starts. Without this capability, the app stops with `Check failed` in `partition_address_space.cc` on a device. The simulator does not have this limit. The entitlement is in `cobalt/shell/app/tvos-entitlements.plist`. The provisioning profile must also contain it.

To get a development profile, pair the Apple TV with the Mac in Xcode, Window, Devices and Simulators. Then let Xcode create the profile:

1. Create a tvOS app project in Xcode with the bundle identifier `com.deividfortuna.dedtube`.
2. Add the Extended Virtual Addressing capability in Signing & Capabilities.
3. Keep automatic signing on and run the project once on the Apple TV.

Xcode registers the Apple TV and creates "tvOS Team Provisioning Profile: com.deividfortuna.dedtube" in `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.

Find the hash of the development certificate:

```
security find-identity -v -p codesigning
```

Generate the output directory, then add the signing arguments to its `args.gn` file:

```
cobalt/build/gn.py -p tvos-arm64-device -C devel --no-rbe
cat >> out/tvos-arm64-device_devel/args.gn <<'EOF'
ios_code_signing_identity = "<identity hash>"
ios_code_signing_identity_description = ""
ios_mobileprovision_files = [ "/path/to/profile.mobileprovision" ]
EOF
gn gen out/tvos-arm64-device_devel
autoninja -C out/tvos-arm64-device_devel cobalt
```

## Run on a device

Install and start the app. Use the device name that `xcrun devicectl list devices` shows:

```
xcrun devicectl device install app --device "<device name>" out/tvos-arm64-device_devel/DedTube.app
xcrun devicectl device process launch --device "<device name>" --terminate-existing com.deividfortuna.dedtube
```

Add `--console` to the launch command to show the log. When you stop `devicectl`, the app also stops.

## Upload to TestFlight

TestFlight needs a release build of the device target, signed for the App Store.

Prepare these items once in the Apple Developer portal and in App Store Connect:

1. Register the bundle identifier `com.deividfortuna.dedtube` as an App ID with the tvOS platform. Enable the Extended Virtual Addressing capability on the App ID.
2. Create an Apple Distribution certificate. Xcode can create it in Settings, Accounts, Manage Certificates.
3. Create an App Store provisioning profile for tvOS with that App ID and that certificate. Download the `.mobileprovision` file. If you change the capabilities of the App ID, create the profile again. An old profile does not contain the new entitlements.
4. Create the app record in App Store Connect with the tvOS platform and the same bundle identifier.
5. Create an App Store Connect API key with the Developer role. Save the `.p8` file in `~/.appstoreconnect/private_keys/`.

Find the hash of the distribution certificate:

```
security find-identity -v -p codesigning
```

Build the release bundle. The compile takes some hours and does not need the certificate, so you can build with code signing off while you prepare the portal items:

```
cobalt/build/gn.py -p tvos-arm64-device -C gold --no-rbe
echo 'ios_enable_code_signing = false' >> out/tvos-arm64-device_gold/args.gn
gn gen out/tvos-arm64-device_gold
autoninja -C out/tvos-arm64-device_gold cobalt
```

When the certificate and the profile are installed, turn code signing on. Only the bundle steps run again:

```
sed -i '' '/ios_enable_code_signing/d' out/tvos-arm64-device_gold/args.gn
cat >> out/tvos-arm64-device_gold/args.gn <<'EOF'
ios_code_signing_identity = "<Apple Distribution hash>"
ios_code_signing_identity_description = ""
ios_mobileprovision_files = [ "/path/to/DedTube_AppStore.mobileprovision" ]
EOF
gn gen out/tvos-arm64-device_gold
autoninja -C out/tvos-arm64-device_gold cobalt
```

Increase `CFBundleVersion` in `cobalt/shell/app/tvos-Info.plist` before each upload. App Store Connect rejects a build number that it already has.

Package the bundle as an `.ipa` file:

```
rm -rf Payload DedTube.ipa
mkdir Payload
cp -R out/tvos-arm64-device_gold/DedTube.app Payload/
zip -qr DedTube.ipa Payload
```

Validate the package, then upload it:

```
xcrun altool --validate-app -t appletvos -f DedTube.ipa --apiKey <key id> --apiIssuer <issuer id>
xcrun altool --upload-app -t appletvos -f DedTube.ipa --apiKey <key id> --apiIssuer <issuer id>
```

The Transporter app from the Mac App Store can upload the same `.ipa` file without an API key.

App Store Connect processes the build for some minutes. Then add testers to the build in the TestFlight tab.

## App icon

tvOS needs a layered app icon and top shelf images. They are in `cobalt/shell/app/ios/resources/Assets.xcassets/AppIcon.brandassets`. The app icon has three layers: front, middle, and back. To change an image, replace the PNG file and keep the size:

| Image | Size at 1x | Size at 2x |
| --- | --- | --- |
| App icon layers | 400x240 | 800x480 |
| App Store icon layers | 1280x768 | none |
| Top shelf image | 1920x720 | 3840x1440 |
| Top shelf image wide | 2320x720 | 4640x1440 |

The back layer must be opaque. The front layer and the middle layer can have transparent areas.

## Platform differences

The `h5vcc.tizenTube` JavaScript API has these differences on tvOS:

| Call | Behaviour on tvOS |
| --- | --- |
| `InstallAppFromURL` | Returns `false`. tvOS does not permit app installation from a URL. |
| `GetVersion` | Returns `CFBundleShortVersionString`. |
| `GetArchitecture` | Returns `arm64` or `x86_64`. |
| `GetBrandAndModel` | Returns the Apple TV name from `UIDevice`. |
| `SetFrameRate` | Stores the frame rate. The video renderer applies it with display criteria matching when the next playback starts. |
| `EnterPIP` | Does nothing. |
| `HasSystemFeature` | Returns `false`. |

Display criteria matching only has an effect when the user enables "Match Frame Rate" in the Apple TV video settings.
