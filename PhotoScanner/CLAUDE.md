# CLAUDE.md — Photo Scanner

Context for Claude Code sessions working on this iOS app. Read this first.

## What this is

A native iOS app (Swift / SwiftUI) that scans physical photo prints: live camera
→ Vision rectangle detection → auto-capture when stable → Core Image enhancement
→ save to Photos. On-device only. MVP scope. Full spec in `docs/PhotoScanner_PRD.md`.

## Toolchain reality (important)

- **iOS apps build only on macOS with Xcode.** There is no Linux/cloud build path.
- **This app cannot be meaningfully tested in the Simulator** — the camera and
  Vision framework need real hardware. Test on a physical iPhone (12 or newer).
- The project is defined by **`project.yml` (XcodeGen)**, not a checked-in
  `.xcodeproj`. After adding/removing/renaming Swift files, run
  `xcodegen generate`. The `.xcodeproj` is git-ignored.

## Build / run / test commands (on the Mac)

```bash
# Regenerate the Xcode project after file changes
xcodegen generate

# Build from the command line (catches compile errors without opening Xcode).
# Use a real device destination; replace the name with your device's.
xcodebuild -project PhotoScanner.xcodeproj -scheme PhotoScanner \
  -destination 'platform=iOS,name=YOUR_IPHONE_NAME' build

# List available destinations / devices
xcodebuild -project PhotoScanner.xcodeproj -scheme PhotoScanner -showdestinations

# Day-to-day: build & run with ⌘R in Xcode (best for SwiftUI previews + device deploy)
```

A good loop for Claude: edit Swift → `xcodegen generate` (if files changed) →
`xcodebuild ... build` → read compiler errors → fix → repeat. Physical scanning
behavior (detection feel, capture timing, image quality) must be judged by the
human on-device.

## Architecture map

- `Services/CameraService` — AVCaptureSession, streams video frames, returns a
  frame on capture, controls the torch.
- `Services/VisionService` — `VNDetectRectanglesRequest` per frame, stability
  tracking, fires `onStableCapture` after 1s of stillness.
- `Services/ImageProcessingService` — Core Image pipeline (perspective correct +
  crop, auto-adjust, noise reduction, unsharp mask) + thumbnail.
- `Services/PhotoLibraryService` — PhotoKit save into a named album (created on demand).
- `Screens/ScanViewModel` — coordinates the whole capture loop; owns the services;
  keeps processing off the main thread.
- `Screens/*`, `Components/*` — SwiftUI views.
- `Models/AppSettings` — UserDefaults-backed settings shared across the app.

## Known areas to verify / tune on-device (first-draft caveats)

This code was generated without a compiler. Expect to fix small issues on first
build. Pay special attention to:

1. **Overlay alignment** — the detection border is mapped from Vision's full-frame
   normalized coords onto a `.resizeAspectFill` preview. If the green rectangle
   doesn't sit exactly on the photo edges, map through
   `AVCaptureVideoPreviewLayer.layerRectConverted(fromMetadataOutputRect:)`.
2. **Camera/buffer orientation** — `CameraService` forces portrait. If captures
   come out rotated, adjust the connection orientation and the Vision orientation.
3. **Detection thresholds** — aspect-ratio bounds, `minimumSize`, and the
   stability tolerance in `VisionService` are starting guesses; tune against real
   prints (4x6, 3x5, faded, glossy).
4. **Capture quality** — capture currently reuses the live video frame for
   coordinate alignment. If quality is insufficient, switch to
   `AVCapturePhotoOutput` and remap the stored normalized corners onto the photo.
5. **`autoAdjustmentFilters`** — used for Step 3 "auto enhancement" (there is no
   single `CIAutoAdjust` filter despite the PRD wording).

## MVP build sequence (test each step on-device before moving on — PRD §16)

- [ ] 1. Camera feed renders full-screen
- [ ] 2. Rectangle detection overlay in real time
- [ ] 3. Auto-capture (stability timer, shutter sound)
- [ ] 4. Image processing pipeline — verify quality on real photos
- [ ] 5. PhotoKit save + album creation
- [ ] 6. Thumbnail strip (display, scroll, tap to preview)
- [ ] 7. Settings screen wired up
- [ ] 8. Error handling (permission denied, save failure)
- [ ] 9. Polish (animations, overlay states, dark mode)

## Conventions

- No third-party dependencies — Apple frameworks only.
- iOS 16 minimum; guard newer APIs with `#available`.
- Keep all image processing off the main thread; only mutate `@Published` UI
  state on the main thread.
