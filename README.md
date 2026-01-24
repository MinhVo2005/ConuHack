# ConUHacks26

# G-Lovers

**Jarvis-inspired gesture control interface for hands-free computing**

A single smart glove that replaces mouse and keyboard using finger gestures, hand motion tracking, and voice input — designed for environments where touching peripherals is impractical, unsafe, or impossible.

---

## Social Impact Use Cases

| Field | Problem | How GestureFlow Helps |
|-------|---------|----------------------|
| **Healthcare** | Surgeons/nurses can't touch keyboards during sterile procedures | Navigate patient records, imaging software, and EHRs without breaking sterile field |
| **Accessibility** | Users with RSI, limited mobility, or motor impairments struggle with traditional input | Hands-free control reduces strain; customizable gestures accommodate different abilities |
| **Industrial/Labs** | Workers in cleanrooms, factories, or labs wear PPE gloves | Operate systems without removing protective equipment |
| **Rehabilitation** | Physical therapists lack quantitative finger mobility data | Track and log finger movement metrics for recovery monitoring |
| **Food Service** | Health codes prohibit touching shared surfaces | Browse recipes, manage orders without cross-contamination |

---

## Hardware

| Component | Model | Purpose |
|-----------|-------|---------|
| Microcontroller | ESP32-WROOM-32U | Bluetooth HID, sensor processing |
| IMU | MPU-9250 (9-axis) | Hand orientation → cursor control |
| Flex Sensors [DIY](https://www.youtube.com/watch?v=zUN2ZYdYAUo) | x5 (one per finger) [Velostat](https://abra-electronics.com/robotics-embedded-electronics/e-textiles/materials/1361-ada-pressure-sensitive-conductive-sheet-velostat-linqstat-1361-ada.html) | Finger bend detection (binary: bent/not bent) |
|Touch Sensor (Maybe)| ??? | Replace flex sensors|
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
| Desktop Client | Python | Receives BLE data, controls cursor/keyboard, STT processing |
| Speech-to-Text | Whisper API / Google STT / ElevenLabs | Voice → text (streamed from glove mic to desktop) |
| Dashboard | Web (React or HTML) | Real-time gesture display, connection status, input log |

---

## Gesture Mapping (32 States)

5 fingers × binary (bent/not bent) = 2⁵ = **32 possible gestures**

| Gesture | Binary | Action |
|---------|--------|--------|
| All open | `00000` | Idle / tracking mode |
| Index only | `01000` | Left click |
| Index + Middle | `01100` | Right click |
| Fist | `11111` | Hold to drag |
| Thumb only | `10000` | Scroll mode (IMU Y-axis = scroll) |
| Pinky only | `00001` | Voice input toggle |

*22 more mappings customizable*

---

## Dashboard Metrics

- Connection status (BLE connected/disconnected)
- Current gesture (visual hand diagram)
- Active mode (cursor / scroll / voice)
- Recent inputs log (gesture history + voice transcriptions)

---

## Architecture

```
[Glove]                      [Desktop]
  │                              │
  ├─ Flex sensors (x5)           │
  ├─ MPU-9250 (orientation)      │
  ├─ Microphone ──────────────►  │ ── Speech-to-Text (Whisper)
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
2. Run desktop client (`python client.py`)
3. Pair glove via Bluetooth
4. Open dashboard (`localhost:3000`)
5. Calibrate flex sensors (follow on-screen prompts)


## Future Improvements

- Two-glove mode (1024 gestures)
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
