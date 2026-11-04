# Aeration demonstrator setup

## Arduino

Open source/Akvarium/Akvarium.ino in the Arduino IDE and select Nano ATmega328P. Only Arduino core headers are used. The retained project report records a successful AVR compile; no firmware upload was performed during this portfolio preparation.

| Channel | LOW input | PWM input |
|---|---|---|
| K1 | D4 | D5 |
| K2 | D8 | D9 |
| K3 | D7 | D6 |
| K4 | D10 | D11 |

Two L298N drivers provide four motor channels. ENA/ENB must be enabled externally. D0/D1 serve hardware serial. Confirm driver wiring and power separately before connecting motors.

## Delphi

The retained project targets Delphi 10.3 Win32. Open source/Delphi/Akvarium.dproj in a compatible environment. The source uses VCL and still references DevExpress VCL units and CPort; those third-party dependencies are not distributed. A local build report exists, but this source snapshot is not dependency-free.

The application uses Windows serial APIs at 9600 baud, 8N1, with newline-delimited JSON. Example command:

```json
{"cmd":"set","m1":70,"m2":70,"m3":50,"m4":0}
```

Motor values are integers from 0 to 100. Invalid packets are rejected. In MANUAL mode choose values and send; in AUTO mode the model calculates commands using configured limits. O₂ is simulated, not measured. This demonstration is not a validated oxygen-control installation. A serial disconnection does not prove that physical motors have stopped.
