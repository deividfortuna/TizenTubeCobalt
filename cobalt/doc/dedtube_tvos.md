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

A device build needs a code signing identity and two provisioning profiles. One profile is for the app. The other profile is for the Top Shelf extension, which has the bundle identifier `com.deividfortuna.dedtube.topshelf`.

The app needs the Extended Virtual Addressing capability. PartitionAlloc reserves large address space pools when the app starts. Without this capability, the app stops with `Check failed` in `partition_address_space.cc` on a device. The simulator does not have this limit. The entitlement is in `cobalt/shell/app/tvos-entitlements.plist`. The provisioning profile of the app must also contain it.

The app and the Top Shelf extension share data through the app group `group.com.deividfortuna.dedtube`. The entitlement is in `cobalt/shell/app/tvos-entitlements.plist` and in `cobalt/app/tvos/top_shelf/entitlements.plist`. The two provisioning profiles must also contain it.

To get the development profiles, pair the Apple TV with the Mac in Xcode, Window, Devices and Simulators. Then let Xcode create the profiles:

1. Create a tvOS app project in Xcode with the bundle identifier `com.deividfortuna.dedtube`.
2. Add the Extended Virtual Addressing capability in Signing & Capabilities.
3. Add the App Groups capability with the group `group.com.deividfortuna.dedtube`.
4. Add a TV Top Shelf Extension target with the bundle identifier `com.deividfortuna.dedtube.topshelf`. Add the App Groups capability with the same group to this target.
5. Keep automatic signing on and run the project once on the Apple TV.

Xcode registers the Apple TV and creates one profile for each bundle identifier in `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.

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
ios_mobileprovision_files = [
  "/path/to/app_profile.mobileprovision",
  "/path/to/top_shelf_profile.mobileprovision",
]
EOF
gn gen out/tvos-arm64-device_devel
autoninja -C out/tvos-arm64-device_devel cobalt
```

The build selects the profile that agrees with each bundle identifier.

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

1. Register the app group `group.com.deividfortuna.dedtube`.
2. Register the bundle identifier `com.deividfortuna.dedtube` as an App ID with the tvOS platform. Enable the Extended Virtual Addressing capability on the App ID. Enable the App Groups capability and select the app group.
3. Register the bundle identifier `com.deividfortuna.dedtube.topshelf` as an App ID with the tvOS platform. Enable the App Groups capability and select the app group.
4. Create an Apple Distribution certificate. Xcode can create it in Settings, Accounts, Manage Certificates.
5. Create one App Store provisioning profile for tvOS for each App ID, with that certificate. Download the two `.mobileprovision` files. If you change the capabilities of an App ID, create its profile again. An old profile does not contain the new entitlements.
6. Create the app record in App Store Connect with the tvOS platform and the bundle identifier `com.deividfortuna.dedtube`. The Top Shelf extension does not need an app record.
7. Create an App Store Connect API key with the Developer role. Save the `.p8` file in `~/.appstoreconnect/private_keys/`.

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

When the certificate and the profiles are installed, turn code signing on. Only the bundle steps run again:

```
sed -i '' '/ios_enable_code_signing/d' out/tvos-arm64-device_gold/args.gn
cat >> out/tvos-arm64-device_gold/args.gn <<'EOF'
ios_code_signing_identity = "<Apple Distribution hash>"
ios_code_signing_identity_description = ""
ios_mobileprovision_files = [
  "/path/to/DedTube_AppStore.mobileprovision",
  "/path/to/DedTube_TopShelf_AppStore.mobileprovision",
]
EOF
gn gen out/tvos-arm64-device_gold
autoninja -C out/tvos-arm64-device_gold cobalt
```

Increase `cobalt_bundle_version` in `cobalt/app/tvos/bundle.gni` before each upload. App Store Connect rejects a build number that it already has. The app and the Top Shelf extension get the same build number from this file.

The version is `cobalt_bundle_short_version` in the same file. When you merge an upstream release, set it to the `version_name` value in `cobalt/android/BUILD.gn`. The TizenTube script compares this version with the newest release and shows an update message if it is older.

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

## Continue Watching in the Top Shelf

When DedTube is in the top row of the Home screen and has the focus, the Top Shelf shows a "Continue Watching" row. Each item shows the thumbnail and the playback progress of a video. When you select an item, DedTube opens the video at the saved position.

The app saves the position of a video during playback. These rules apply:

- The app saves a video when the position is 30 seconds or more.
- The app removes a video when the position is 95% of the duration or more.
- The row keeps the 10 most recent videos.
- The app does not save live streams.

The row shows only the videos that you watch in DedTube on this Apple TV. It does not read the watch history of the YouTube account.

If the row is empty, tvOS shows the static Top Shelf image.

| Part | Location | Function |
| --- | --- | --- |
| Recorder | `cobalt/browser/tvos/continue_watching/continue_watching_recorder.mm` | Reads the video, the title, and the position from the page and its media session. |
| Store | `cobalt/browser/tvos/continue_watching/continue_watching_store.mm` | Keeps the videos in the user defaults of the app group. |
| Top Shelf extension | `cobalt/app/tvos/top_shelf` | Reads the store and gives the row to tvOS. |
| Link | `cobalt/browser/tvos/continue_watching/continue_watching_link.mm` | Changes `dedtube://watch?v=<video id>&t=<seconds>` to the YouTube address of the video. |

## Now Playing

During playback, DedTube gives the video to the Now Playing function of tvOS. Control Center and the Home app then show the title, the channel, the thumbnail, and the playback position.

Other devices can also control the playback through Now Playing. These commands are available when the YouTube page supports them:

- Play and pause.
- Next video and previous video.
- Skip 10 seconds forward or backward.
- Go to a position in the video.

When the playback stops, DedTube removes the video from Now Playing.

DedTube sends a skip command to the page as a seek to the position 10 seconds away. The YouTube page only shows a paused preview when it gets a seek command without a position.

When DedTube comes back from the Home screen without a link, the YouTube page gives the title again but does not give the thumbnail. DedTube then uses the thumbnail that the same title had before.

| Part | Location | Function |
| --- | --- | --- |
| Publisher | `cobalt/browser/tvos/now_playing/now_playing_publisher.mm` | Reads the media session of the page, gives the data to `MPNowPlayingInfoCenter`, and sends the commands from `MPRemoteCommandCenter` to the page. |

## Siri Remote ring

A circle with the finger on the clickpad ring moves the playback position. A clockwise circle moves it forward and a counterclockwise circle moves it back. A full circle is 90 seconds. Push the center of the clickpad to confirm the position.

On an Apple TV, DedTube gets the finger position from the game controller interface and sends it to the YouTube page as touch events. The page reads only the horizontal movement, so it cannot follow a circle. DedTube finds the rotation before the page gets the touch:

- A touch becomes a rotation when the finger turns 45 degrees around the center and stays out of the center area.
- During a rotation, the page gets no touch events. For each 20 degrees, DedTube sends a Right key for a clockwise turn or a Left key for a counterclockwise turn.
- In the player, each key moves the scrub bar 5 seconds.

A swipe goes through the center area, so it stays a touch. The center area has a radius of 0.4, where 1 is the edge of the clickpad. The limits come from recorded touches of a Siri Remote: the swipes turned 13 degrees or less, and the finger on the ring stayed at a distance of 0.48 or more from the center.

The simulator has no game controller for the remote, so it does not use this code.

| Part | Location | Function |
| --- | --- | --- |
| Rotation | `content/browser/renderer_host/siri_remote_ring_rotation.cc` | Calculates the rotation steps from the finger positions. |
| Touch input | `content/browser/renderer_host/render_widget_host_view_tvos_uiview.mm` | Sends the keys and stops the touch events during a rotation. |

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
