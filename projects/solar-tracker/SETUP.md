# Manual solar tracker setup

The sketch folder is source/Solar_tracker. Open Solar_tracker.ino with the Arduino IDE; target Nano ATmega328P at 16 MHz. Required external dependencies: Arduino AVR core, OneButton 2.6.2, LiquidCrystal_I2C and the author’s custom myDC3231 library. The custom RTC dependency is not bundled, so this snapshot alone is not a self-contained build package. Existing builds were made in the author’s development environment.

| Signal | Nano pin |
|---|---|
| LEFT / RIGHT / UP / DOWN / MID buttons, to GND | D6 / D5 / D7 / D8 / D4 |
| LEFT / RIGHT / UP / DOWN relay inputs, active LOW | D12 / D11 / D10 / D9 |
| LEFT / RIGHT limits | D3 / D2 |
| UP / DOWN limits, external 20 kΩ pull-up | A6 / A7 |
| SDA / SCL | A4 / A5 |

LCD address 0x27; DS3231 address 0x68. A6/A7 are analogue-only inputs. Their actual voltage thresholds require bench verification.

Hold a direction to move, release to stop; a double-click latches a direction. MID held for 3 seconds stops all outputs. Opposing commands are interlocked. Reversal delay is 700 ms; continuous runtime is limited to 60 seconds. MID short-click changes the display. RTC/solar data are informational; there is no AUTO motor tracking.

Start bench checks with motors disconnected. Confirm the relay contact wiring, actual limit levels, power supply, fuse and physical emergency-stop circuit before motor tests. Firmware state alone does not validate relay contacts or mechanical safety. Source records report successful software tests; physical validation remains outstanding.
