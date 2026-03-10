# App Icon Assets

Place the following files in this directory:

1. **`app_icon.png`** — Full app icon, 1024×1024 PNG, with background.
2. **`app_icon_foreground.png`** — Foreground-only layer for Android adaptive icons.
   - Canvas should be 108dp (432px at xxxhdpi). The safe zone is the inner 72dp (288px).
   - Keep important content within the center safe zone; the outer area may be clipped.

## Generate Icons

After placing the images, run from the `frontend/` directory:

```bash
dart run flutter_launcher_icons
```

This generates all required icon sizes for both Android and iOS using the configuration in `pubspec.yaml`.
