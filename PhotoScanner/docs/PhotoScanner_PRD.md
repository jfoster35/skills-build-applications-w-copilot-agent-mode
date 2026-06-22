# Photo Scanner App — Product Requirements Document
**Version:** 1.0 (MVP)  
**Platform:** iOS  
**Development Method:** Claude Code  
**Status:** Ready for development

---

## 1. Overview

A native iOS app that allows users to digitize physical photo prints quickly and easily using their iPhone camera. The app guides the user to hold their phone above a photo, automatically detects the photo edges, captures the scan, applies subtle enhancement, and saves it to the native iOS Photos app.

The MVP covers the core scanning experience only. Restoration, monetization, and physical cradle integration are post-MVP phases.

---

## 2. Goals

- Make scanning physical photos as fast and frictionless as possible
- Produce noticeably better output than simply taking a photo with the camera app
- Save directly to the user's native Photos library — no cloud dependency, no account required
- Run entirely on-device — no internet connection needed

---

## 3. Out of Scope for MVP

The following are explicitly excluded from this version:

- AI-powered photo restoration (scratches, heavy fading, water damage)
- Monetization / in-app purchases / StoreKit
- Physical cradle integration or calibration features
- Negatives or slide scanning
- Social sharing features
- Cloud backup or sync
- Android support
- Onboarding tutorial

---

## 4. Technical Stack

| Component | Technology |
|---|---|
| Language | Swift |
| Minimum iOS Version | iOS 16 |
| UI Framework | SwiftUI |
| Camera & Edge Detection | AVFoundation + Vision framework |
| Image Enhancement | Core Image (CIFilter pipeline) |
| Photo Library Access | PhotoKit |
| No external dependencies | All Apple-native frameworks only |

---

## 5. Permissions Required

The app requires the following iOS permissions. Appropriate usage description strings must be included in Info.plist:

- **Camera** — `NSCameraUsageDescription`: "Used to scan your physical photos."
- **Photo Library (add only)** — `NSPhotoLibraryAddUsageDescription`: "Saves your scanned photos to your Photos library."

---

## 6. App Structure

The MVP has three screens:

1. **Scan Screen** — primary camera view (default/home screen)
2. **Review Screen** — thumbnail strip review after scanning
3. **Settings Screen** — minimal settings accessible via gear icon

There is no navigation bar. The Scan Screen is the root view. Settings is presented as a modal sheet.

---

## 7. Scan Screen (Primary View)

### 7.1 Layout

- Full-screen live camera feed (portrait orientation)
- Overlay showing detected photo boundary (animated green rectangle border when photo is detected)
- **Top-right corner:** two icon buttons — Settings (gear icon) and Flash toggle (lightning bolt icon)
- **Bottom of screen:** horizontal scrollable thumbnail strip showing scanned photos from the current session
- **No shutter button** — capture is automatic

### 7.2 Photo Detection Behavior

Use the **Vision framework** (`VNDetectRectanglesRequest`) to continuously analyze the camera feed.

Detection criteria before triggering auto-capture:
- A rectangle is detected with confidence > 0.85
- The detected rectangle occupies at least 30% of the frame
- The rectangle aspect ratio falls within expected photo print ratios (roughly 3:2 to 4:3)
- The detected rectangle is stable for 1.0 seconds (no significant movement between frames)

When all criteria are met:
1. Play a soft shutter sound
2. Capture the frame
3. Process the image (see Section 8)
4. Add thumbnail to the bottom strip
5. Resume detection for the next photo

### 7.3 Detection Overlay

- When no photo is detected: no overlay shown
- When a photo is partially detected but not yet stable: show a white dashed rectangle border
- When detection criteria are met and stability timer is counting: show an animated green rectangle border that fills/progresses to indicate the capture is imminent
- After capture: brief flash animation, then resume

### 7.4 Flash Toggle

- Default state: OFF
- Tap lightning bolt icon to toggle ON/OFF
- When ON: icon is highlighted (yellow tint)
- Applies torch mode via `AVCaptureDevice.torchMode`

### 7.5 Session Persistence

- Scanned photos persist in the thumbnail strip for the duration of the app session
- Closing and reopening the app starts a fresh session
- No session save/restore required in MVP

---

## 8. Image Processing Pipeline

Triggered immediately after each capture. Runs asynchronously on a background thread. UI remains responsive during processing.

### Step 1 — Perspective Correction
Apply `CIPerspectiveCorrection` using the four corner points returned by the Vision rectangle detection to remove angle distortion.

### Step 2 — Auto Crop
Crop the image precisely to the detected rectangle boundary, removing all background.

### Step 3 — Auto Enhancement
Apply `CIAutoAdjust` to automatically correct brightness, contrast, and color balance. This is a single-call filter that analyzes the image and applies optimal adjustments.

### Step 4 — Noise Reduction
Apply `CINoiseReduction` with conservative settings (inputNoiseLevel: 0.02, inputSharpness: 0.4) to reduce grain without softening detail.

### Step 5 — Gentle Sharpening
Apply `CIUnsharpMask` with light settings (inputRadius: 2.5, inputIntensity: 0.5) to recover slight sharpness.

### Step 6 — Save to Photos
Save the processed image to the iOS Photos library using `PHPhotoLibrary.shared().performChanges`. Save to an album named **"Photo Scanner"** — create the album if it does not already exist.

### Step 7 — Generate Thumbnail
Downscale the processed image to 120x120pt for display in the thumbnail strip.

---

## 9. Thumbnail Strip

- Horizontal scroll view pinned to the bottom of the Scan Screen
- Height: 100pt
- Each thumbnail: 80x80pt, rounded corners (8pt radius), with a subtle drop shadow
- Thumbnails appear left to right in order of capture, newest on the right
- Strip auto-scrolls to show the most recent thumbnail after each capture
- Tapping a thumbnail opens a full-screen preview of that scan (modal, dismissible with swipe down or X button)
- The full-screen preview shows the enhanced image only (no before/after in MVP)
- Strip is empty at session start; shows a subtle placeholder hint ("Your scans will appear here") until the first photo is captured

---

## 10. Settings Screen

Presented as a modal sheet from the gear icon. Keep minimal for MVP.

### Settings Options

| Setting | Type | Default | Description |
|---|---|---|---|
| Flash | Toggle | OFF | Mirror of the flash toggle on the main screen |
| Album Name | Text field | "Photo Scanner" | Name of the Photos album scans are saved to |
| Save Original | Toggle | OFF | If ON, saves the unprocessed capture alongside the enhanced version |
| Detection Sensitivity | Segmented control: Low / Medium / High | Medium | Adjusts the Vision confidence threshold (Low: 0.75, Medium: 0.85, High: 0.95) |
| Auto Enhancement | Toggle | ON | When OFF, skips the entire Core Image processing pipeline (Steps 3–5). Perspective correction and crop still apply. Image is saved as-captured for faithful archival output. |

### Settings Screen Layout
- Navigation title: "Settings"
- Close button (X) top right
- Grouped list style (iOS native)
- Version number displayed at the bottom in small grey text

---

## 11. Error Handling

| Scenario | Behavior |
|---|---|
| Camera permission denied | Show inline message with button to open iOS Settings |
| Photo library permission denied | Show inline message with button to open iOS Settings |
| Photo save failure | Show brief toast notification: "Could not save photo. Check storage." |
| No photo detected after 30 seconds | No action — detection continues silently |
| Processing failure | Skip enhancement, save the raw cropped image, show brief toast: "Enhancement skipped." |

---

## 12. Performance Requirements

- Detection overlay must update at minimum 15fps to feel responsive
- Time from capture trigger to thumbnail appearing in strip: under 2 seconds on iPhone 12 or newer
- App must not request more than one camera frame at a time for processing
- Memory: release processed full-resolution images after saving; retain thumbnails only in session

---

## 13. Visual Design

- **Color scheme:** Dark mode preferred as default (reduces glare reflection on glossy photos)
- **Accent color:** Soft green (#4CAF50) for detection overlay and active states
- **Background:** Near-black (#1C1C1E) for UI chrome
- **Typography:** SF Pro (system default)
- **Icons:** SF Symbols throughout (no custom icon assets needed for MVP)
- The camera feed itself is always full-screen — UI elements float over it

---

## 14. App Icon & Name

- App name: **TBD** (placeholder: "Photo Scanner" for development)
- App icon: TBD — use a placeholder for MVP build

---

## 15. File & Project Structure

Suggested Xcode project structure:

```
PhotoScanner/
├── App/
│   ├── PhotoScannerApp.swift
│   └── ContentView.swift
├── Screens/
│   ├── ScanView.swift
│   ├── SettingsView.swift
│   └── PhotoPreviewView.swift
├── Components/
│   ├── ThumbnailStrip.swift
│   ├── DetectionOverlay.swift
│   └── FlashToggleButton.swift
├── Services/
│   ├── CameraService.swift          — AVFoundation camera session management
│   ├── VisionService.swift          — Rectangle detection via Vision framework
│   ├── ImageProcessingService.swift — Core Image enhancement pipeline
│   └── PhotoLibraryService.swift    — PhotoKit save and album management
├── Models/
│   └── ScannedPhoto.swift           — Model for a captured scan (id, thumbnail, full image URL)
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

## 16. MVP Build Sequence

Build and test in this order. Do not proceed to the next step until the current step works correctly on a physical device.

1. **Camera feed** — AVFoundation session, full-screen preview rendering
2. **Rectangle detection** — Vision overlay showing detected boundaries in real time
3. **Auto-capture** — stability timer, shutter sound, capture trigger
4. **Image processing** — Core Image pipeline, verify output quality on real photos
5. **PhotoKit save** — save to Photos, create album, verify on device
6. **Thumbnail strip** — display, scroll, tap to preview
7. **Settings screen** — modal, all controls wired up
8. **Error handling** — permission denied flows, save failure toast
9. **Polish** — animations, detection overlay states, dark mode refinement

---

## 17. Testing Notes

- **Must test on a physical device** — camera and Vision framework do not work reliably in Simulator
- Test with a variety of real photo prints: 4x6, 3x5, glossy, matte, very old faded prints, black and white
- Test in different lighting conditions: bright natural light, indoor overhead light, dim light
- Test flash mode with glossy photos to verify glare behavior
- Verify Photos album is created correctly and scans appear in correct order

---

## 18. Future Phases (Post-MVP Reference)

These are documented here for context but must not influence MVP development scope:

**Phase 2 — AI Restoration**
- Per-photo restoration review screen
- Before/after swipe comparison
- Cloud AI model integration for heavy damage repair
- StoreKit credit pack and unlimited pass monetization

**Phase 3 — Physical Cradle**
- 3D print file (STL) bundled with unlimited restoration purchase
- Calibration mode to verify phone height and alignment
- LED lighting integration notes

**Phase 4 — Polish & Growth**
- App Store listing, screenshots, preview video
- App name and icon finalization
- Onboarding flow for first-time users
- Android evaluation

---

*Document prepared for handoff to Claude Code. All decisions reflect conversations with the product owner. Revisit this document before beginning Phase 2.*
