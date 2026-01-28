# ConUHacks26

# G-Lovers

**Dynamic banking application that utilizes a Jarvis-inspired gesture control interface for hands-free computing**

An two-in-one banking application that allows users to keep track of local real-time weather data and features unique privacy features.
---

## Social Impact Use Cases

| Problem | How GestureFlow Helps |
|-------|---------|----------------------|
| **Accessibility** | Users with RSI, limited mobility, or motor impairments struggle with traditional input | Hands-free control reduces strain; customizable gestures accommodate different abilities |
| **Demographic** | The integration of a haptic glove and speech to text operation allows all demographics including the elderly to use the application with ease. |
| **Privacy** | "Invisibility Mode" permits the user to access their private banking information without the risk of their financial data being seen by others.|
| **Efficiency** | The inclusion of real-time weather data on the dashboard of the banking application permits the users to check many forms of information on a single platform.|
| **Visuals** | Unlike traditional banking applications, TheGardens' dynamic visual style keeps the layout modern and appealing|


---

## Hardware

| Component | Model | Purpose |
|-----------|-------|---------|
| Microcontroller | ESP32-WROOM-32U | Bluetooth HID, sensor processing |
| IMU | MPU-9250 (9-axis) | Hand orientation → cursor control |
| Microphone | Electret/MEMS mic | Voice-to-text for keyboard replacement |
| Power | USB or LiPo battery | Wired for hackathon demo |
| Glove Base | Any fabric glove | Sensor mounting |

**Wiring Summary:**
- Flex sensors → ESP32 ADC pins (GPIO 32-36)
- MPU-9250 → I²C (SDA: GPIO 21, SCL: GPIO 22)
- Mic → ADC or I2S depending on module

---

## Software

| Layer | Tech | Purpose |
|-------|------|---------|
| Firmware | Arduino IDE + ESP32 core | Sensor reading, BLE HID |
| Desktop Client | JavaScript | Receives BLE data, controls cursor, STT processing |
| Speech-to-Text | ElevenLabs API | Gemini API | Voice → text → Actions (streamed from glove mic or phone to backend server) |
| Banking App Dashboard | IOS (XCode & Dart) | Real-time environment status, theme changing, acciybt balance changes |

## Dashboard Metrics

- Connection status (BLE connected/disconnected)
- Active mode (cursor / voice)
- Recent inputs log (gesture history + voice transcriptions)
---

## Architecture

```
[Glove]                      [Desktop]
  │                              │
  ├─ Flex sensors (x5)           │
  ├─ MPU-9250 (orientation)      │
  ├─ Microphone ──────────────►  │ ── Speech-to-Text (ElevenLabs)
  │                              │
  └─ ESP32 ── BLE HID ────────►  │ ── Cursor/Keyboard Control
                                 │
                                 └─► Dashboard (localhost)
```

---
## Setup

### Setup MPU-9250
- VCC -> 3.3V
- GND -> (-)
- SCL -> 22
- SDA -> 21
- ADO -> GND

## Quick Start

1. Flash ESP32 with firmware (`/firmware`)
2. Run desktop client
3. Pair glove via Bluetooth
4. Open dashboard (`localhost:3000`)
5. Connect mobile application via XCode on a common network


## Future Improvements

- Two-glove mode
- Flex Sensor implementations
- keyboard functionalities
- On-device ML for custom gesture recognition
- Haptic feedback for confirmations

---

## Why Hardware Sensors over Camera/OpenCV?

| Factor | Camera + OpenCV | Hardware Sensors (Our Approach) |
|--------|-----------------|--------------------------------|
| **Occlusion** | Fails when hand is blocked or out of frame | Works regardless of hand position |
| **Lighting** | Sensitive to shadows, glare, low light | Unaffected by lighting conditions |
| **Latency** | Higher (image processing overhead) | Lower (direct sensor readings) |
| **Privacy** | Camera always watching | No visual surveillance |
| **Portability** | Requires fixed camera setup | Self-contained, works anywhere |
| **Sterile environments** | Camera can't be in surgical field | Glove is worn by user |
| **Computational load** | GPU-intensive for real-time tracking | Lightweight processing on ESP32 |
| **Precision** | Struggles with fine finger movements | Direct per-finger measurement |

**TL;DR:** Cameras guess hand position from pixels. We measure it directly.

---
