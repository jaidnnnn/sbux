# LiftLog

A Strong-style workout tracker for Apple Watch Series 3 (watchOS 8) with an iPhone companion (iOS 17+).

- **Watch:** pick a routine, log sets with the Digital Crown, see last time's numbers, tag sets as warm-up / drop / failure, get a rest timer with a wrist tap, and PR alerts. Each session is saved to Apple Health as a strength workout.
- **iPhone:** build routines, browse history, see per-exercise progress charts (best weight, estimated 1RM, volume) and records, and import your Strong history.

Weights are in kilograms. The default rest timer is 90 seconds and can be changed per exercise.

## Build and install

You need a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen), which creates the Xcode project from `project.yml`.

```bash
brew install xcodegen
```

```bash
cd LiftLog && xcodegen && open LiftLog.xcodeproj
```

Then in Xcode:

1. In `project.yml`, change `APP_BUNDLE_ID` from `com.example.liftlog` to something unique to you (for example `com.yourname.liftlog`) and run `xcodegen` again. A free Apple ID cannot sign an ID someone else has used.
2. Select each target (LiftLog and LiftLogWatch) → Signing & Capabilities → pick your Team. A free Apple ID works.
3. Plug in your iPhone with the watch nearby and unlocked. Choose the **LiftLog** scheme and your iPhone, then Run. This installs the phone app.
4. Choose the **LiftLogWatch** scheme and your watch as the destination, then Run. Installing to a Series 3 is slow; give it several minutes.
5. On first workout the watch asks for Health access. Allow it.

With a free Apple ID the apps stop opening after 7 days; run them from Xcode again to renew. Your data is kept. A paid developer account ($99/year) removes that limit.

## Importing from Strong

In Strong: Profile → Settings → Export Strong Data, and save the CSV to Files. In LiftLog on the iPhone: More → Import Strong CSV. This brings in every workout, creates the exercises, and makes a routine for each workout name based on the most recent session. Importing the same file again does not duplicate anything.

## Using it

1. Create or adjust routines on the iPhone. They sync to the watch automatically.
2. On the watch, tap a routine to start. Tap an exercise, then a set.
3. Tap a number and turn the crown (2.5 kg / 1 rep per click), or use − and + for fine steps (0.5 kg). The left button cycles the set type: N, W (warm-up), D (drop), F (failure). Tap Log.
4. The rest timer starts. Your wrist is tapped when it ends; +30s and Skip are on screen.
5. Finish → Save workout. It is sent to the phone when the phone is next in range.

Warm-up sets are excluded from volume and records.

## Tests

The non-UI logic (Strong import, stats, records, watch sync payloads) has unit tests that run without Xcode:

```bash
swift test
```

## Layout

- `Shared/` models, stats, Strong importer, watch sync payloads (compiled into both apps)
- `Watch/` the watchOS app
- `Phone/` the iOS app
- `project.yml` XcodeGen project definition
