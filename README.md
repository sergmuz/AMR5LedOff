# AMR5LedOff

Small Windows utility to completely disable RGB LED lighting on **AceMagic AMR5 (Ryzen 5 5600U)**.

The program sends direct commands to the RGB controller using the **inpoutx64** driver and permanently turns the LEDs OFF.

---

## Features

- Completely disables RGB LEDs
- No GUI (runs silently)
- Very small executable
- Automatically creates a scheduled task
- LEDs stay OFF after reboot
- Writes a small log file for troubleshooting

---

## Installation

1. Download **AMR5LedOff.exe** from the Releases section.
2. Run the program once as Administrator.

On first run the program will automatically create a scheduled task so the LEDs are disabled on every Windows login.

---

## Tested on

- AceMagic AMR5
- Ryzen 5 5600U
- Windows 10
- Windows 11

---

## Download

Download the latest version here:

➡ **[Download AMR5LedOff.exe](../../releases/latest)**

---

## Source code

The full source code is included in this repository.

---

## License

MIT License
