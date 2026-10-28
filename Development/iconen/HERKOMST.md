# Where the icons come from

| File | Used for | Source | License |
|---|---|---|---|
| `logo.png`, `logo.ico` | the app logo in the title bar, on the taskbar and on the shortcut | Creative Connection's own design (the mascot) | Apache 2.0, like the app |
| `power.png` | the power button | Lucide, icon `power`, lucide-static 1.61.0 | ISC |
| `apparaat.png` | a device without its own icon | Lucide, icon `plug`, lucide-static 1.61.0 | ISC |
| `pencil.png` | giving a device its own name | Lucide, icon `pencil`, lucide-static 1.61.0 | ISC |
| `book-open.png` | opening the log | Lucide, icon `book-open`, lucide-static 1.61.0 | ISC |
| `x.png` | closing the log and Help | Lucide, icon `x`, lucide-static 1.61.0 | ISC |
| `info.png` | opening Help | Lucide, icon `info`, lucide-static 1.61.0 | ISC |
| `arrow-left.png` | going back in Help | Lucide, icon `arrow-left`, lucide-static 1.61.0 | ISC |
| `circle-plus.png` | the Add device row | Lucide, icon `circle-plus`, lucide-static 1.61.0 | ISC |
| `copy.png` | copying the log | Lucide, icon `copy`, lucide-static 1.61.0 | ISC |
| `apparaten/tv.png` | a device whose script name starts with "TV" | Lucide, icon `tv`, lucide-static 1.61.0 | ISC |

Lucide is licensed under the ISC License. Some of its icons are derived from Feather (MIT License). Both license texts are in `NOTICE`.

The Lucide icons were fetched as SVG and turned into PNG with a transparent background (96 by 96 pixels). They are white, so the app can tint them itself. `logo.ico` holds the mascot in eight sizes, from 16 to 256 pixels.

A row gets an icon when `apparaten/` holds a PNG named after the first word of the script name, in small letters. A script called "TV living room.ps1" gets `tv.png`. A device without a matching PNG shows the plug.
