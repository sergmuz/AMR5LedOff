# amr5-rgb-off
Utility to completely disable RGB LED lighting on AceMagic AMR5 (Ryzen 5 5600U)

Small Windows utility to completely disable RGB LED lighting on
AceMagic AMR5 (Ryzen 5 5600U).

The program sends direct commands to the RGB controller using the
inpoutx64 driver.

## Features

- turns RGB LEDs completely OFF
- no GUI
- very small executable
- automatically creates a scheduled task so the LEDs stay OFF after reboot

## Installation

1. Download LedOff.exe
2. Run the program once

On first run the program creates a scheduled task so it runs automatically
at Windows login.

## Tested on

AceMagic AMR5  
Ryzen 5 5600U  
Windows 10 / Windows 11
