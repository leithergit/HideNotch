[简体中文](README.zh-CN.md)

# HideNotch

A macOS menu-bar utility that paints the menu bar area on notched screens pure black, so the notch blends in with the menu bar.

## Requirements

- macOS 26 or later
- A MacBook with a notched built-in display (external, non-notched displays are unaffected)

## Installation

1. Open the downloaded `HideNotch-<version>.dmg`.
2. Drag `HideNotch.app` onto the `Applications` icon in the window to install it.
3. First launch: double-click `HideNotch.app` from `~/Applications` or the Applications folder. The app has no Dock icon; once running it only shows an icon in the menu bar.

## Usage

Click the menu-bar icon to see the following menu items:

- **Hide Notch**: toggles the black bar overlay. The checkmark reflects whether it's currently active. Turning it on shows a confirmation prompt first; turning it off, and app launch (including launch at login), do not prompt.
- **Launch at Login**: when checked, the app starts automatically at login. If the system requires approval in System Settings, the menu shows "Launch at Login (Approve in System Settings)"; clicking it again opens the corresponding System Settings page.
- **Quit**: quits the app.

## Languages

The interface is localized into 13 languages: English (default/fallback), Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German, Spanish, Italian, Portuguese, Thai, Vietnamese, and Indonesian. Translations are machine-assisted; corrections are welcome via issues/PRs.

## Known Limitations

- **Lock screen / wake-from-sleep unlock screen**: not handled, the notch is briefly visible — the lock screen does not composite application windows from the current user session.
- **First login screen after reboot (with FileVault enabled)**: not handled, that screen runs in the pre-unlock boot environment where third-party code cannot run.
- **Logout / switch-user login window**: not implemented in v1 (would require installing a pre-login agent that needs administrator privileges).
- **Resolutions / external displays without a notch**: intentionally not handled (nothing to hide without a notch).

## Building from Source

```bash
swift test              # run the unit tests
scripts/build-app.sh    # ad-hoc signed build, installed to ~/Applications for local debugging
scripts/build-dmg.sh    # produce a signed + notarized distributable DMG (dist/HideNotch-<version>.dmg)
```

`scripts/build-dmg.sh` requires the following environment variables (both have defaults, so you usually don't need to set them):

- `HIDENOTCH_SIGN_IDENTITY`: Developer ID Application signing identity, defaults to `Developer ID Application: XIONGGAO LI (Z8NL57N2AP)`.
- `HIDENOTCH_NOTARY_PROFILE`: the keychain profile name used by `xcrun notarytool`, defaults to `HideNotch`.

Before first use on a machine, store your own Apple ID and app-specific password in the keychain profile once (**never** put your Apple ID / password into scripts or the repository):

```bash
xcrun notarytool store-credentials HideNotch \
  --apple-id <your-apple-id> \
  --team-id <your-team-id> \
  --password <app-specific-password>
```

After that, `scripts/build-dmg.sh` will silently sign and notarize using that keychain profile, without needing credentials again.
