# Microsoft Fonts

This module installs Microsoft Windows 11 fonts on your Linux system. These fonts include Arial, Times New Roman, Verdana, Courier New, Cambria, and other commonly used Microsoft fonts that improve web compatibility and document rendering.

## What it does

- Clones a repository containing Windows 11 fonts (shallow clone)
- Installs TTF, TTC, and OTF fonts to the user's local font directory
- Skips fonts that already exist to avoid duplicates
- Rebuilds the font cache to make fonts available system-wide
- Cleans up temporary files after installation

## Prerequisites

- `git` for cloning the font repository
- `fc-cache` (fontconfig) for rebuilding the font cache

## Usage

### Apply Setup

Run the setup script to install Microsoft fonts:

```bash
./apply_ms_fonts_setup.sh
```

The script will:
1. Clone the Windows 11 fonts repository (shallow clone)
2. Create the local fonts directory if needed
3. Copy TTF, TTC, and OTF fonts (skipping existing ones)
4. Rebuild the font cache
5. Verify installation of common fonts
6. Clean up temporary files

### Revert Setup

To remove the installed Microsoft fonts:

```bash
./revert_ms_fonts_setup.sh
```

Or pass `-y` to skip confirmation:

```bash
./revert_ms_fonts_setup.sh -y
```

This will:
- Remove all fonts from the ms-fonts directory
- Rebuild the font cache to update system
- Clean up the empty font directory

## Font Location

Fonts are installed to: `~/.local/share/fonts/ms-fonts/`

## Verification

After installation, you can verify the fonts are available with:

```bash
fc-list : family | grep -E -i "Arial|Times|Verdana|Courier|Cambria"
```

## Notes

- Fonts are installed for the current user only (not system-wide)
- Existing fonts are not overwritten
- The font cache rebuild may take a moment on first run