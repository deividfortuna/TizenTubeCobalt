# DedTube on tvOS

This document tells you how to build and run DedTube on the Apple TV simulator and on an Apple TV device. DedTube is the tvOS build of TizenTube Cobalt.

## Requirements

- macOS with Xcode 16 or later and the tvOS SDK.
- depot_tools on your PATH.
- A checkout of this repository. The examples use the directory name `src`.

## Set up the checkout

Create the `.gclient` file in the parent directory of the checkout. The `name` value must be the directory name of the checkout.

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

A device build needs a code signing identity and a provisioning profile. Generate the output directory, then add the signing arguments to its `args.gn` file:

```
cobalt/build/gn.py -p tvos-arm64-device -C devel --no-rbe
cat >> out/tvos-arm64-device_devel/args.gn <<'EOF'
ios_code_signing_identity = "<identity hash>"
ios_mobileprovision_files = [ "//path/to/profile.mobileprovision" ]
EOF
gn gen out/tvos-arm64-device_devel
autoninja -C out/tvos-arm64-device_devel cobalt
```

Install the bundle with Xcode or with `xcrun devicectl device install app`.

## Upload to TestFlight

TestFlight needs a release build of the device target, signed for the App Store.

Prepare these items once in the Apple Developer portal and in App Store Connect:

1. Register the bundle identifier `com.deividfortuna.dedtube` as an App ID with the tvOS platform.
2. Create an Apple Distribution certificate. Xcode can create it in Settings, Accounts, Manage Certificates.
3. Create an App Store provisioning profile for tvOS with that App ID and that certificate. Download the `.mobileprovision` file.
4. Create the app record in App Store Connect with the tvOS platform and the same bundle identifier.
5. Create an App Store Connect API key with the Developer role. Save the `.p8` file in `~/.appstoreconnect/private_keys/`.

Find the hash of the distribution certificate:

```
security find-identity -v -p codesigning
```

Build the release bundle. Increase `CFBundleVersion` in `cobalt/shell/app/tvos-Info.plist` before each upload. App Store Connect rejects a build number that it already has.

```
cobalt/build/gn.py -p tvos-arm64-device -C gold --no-rbe
cat >> out/tvos-arm64-device_gold/args.gn <<'EOF'
ios_code_signing_identity = "<Apple Distribution hash>"
ios_mobileprovision_files = [ "//path/to/DedTube_AppStore.mobileprovision" ]
EOF
gn gen out/tvos-arm64-device_gold
autoninja -C out/tvos-arm64-device_gold cobalt
```

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

Validation rejects a tvOS app without an App Icon and Top Shelf Image set in the asset catalog. Add the layered icon to `cobalt/shell/app/ios/resources/Assets.xcassets` before the first upload.

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
