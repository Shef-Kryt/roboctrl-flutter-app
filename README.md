# RoboCtrl Flutter App

A cross-platform mobile application for controlling a robotic platform based on **Raspberry Pi Pico (RP2040)** using **Flutter and Dart**.

The application provides remote robot control, Bluetooth communication, real-time sensor monitoring, telemetry visualization, and autonomous route management.

---

## Project Overview

| Parameter               | Description                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| Project type            | Mobile application (Android)                                     |
| Programming language    | Dart                                                             |
| Framework               | Flutter                                                          |
| Communication protocols | Bluetooth Classic (SPP) / Bluetooth Low Energy (BLE)             |
| Hardware platform       | Raspberry Pi Pico (RP2040) — PicoGo / Waveshare robotic platform |

---

# Features

* Bluetooth device scanning and connection (BLE and Classic SPP)
* Robot movement control using a virtual joystick and buttons
* Adjustable movement speed
* RGB LED strip control (static colors and animations)
* Real-time sensor monitoring:

  * Battery voltage
  * Temperature
  * Distance sensor
  * Line sensors
* Telemetry dashboard with real-time graphs
* Autonomous route planner with telemetry recording
* Route editor for movement sequences
* Automatic Bluetooth reconnection after connection loss
* Event logging system with file storage
* Application settings management
* Dark and light themes support (Material 3)

---

# Project Structure

```text
lib/
├── main.dart
│   └── Application entry point and provider initialization
│
├── models/
│   ├── robot_device.dart
│   │   └── Bluetooth device model (BLE / Classic)
│   ├── sensor_reading.dart
│   │   └── Sensor data model (JSON/CSV)
│   ├── route.dart
│   │   └── Robot route model
│   ├── route_step.dart
│   │   └── Movement step model
│   ├── scheduled_task.dart
│   │   └── Scheduled task and telemetry status
│   ├── led_strip.dart
│   │   └── RGB LED configuration model
│   └── line_sensor.dart
│       └── Line sensor calibration model
│
├── providers/
│   ├── bluetooth_provider.dart
│   │   └── Bluetooth communication and telemetry
│   ├── settings_provider.dart
│   │   └── Application settings management
│   └── scheduler_provider.dart
│       └── Autonomous route scheduler
│
├── screens/
│   ├── home_screen.dart
│   ├── dashboard_screen.dart
│   ├── sensors_realtime_screen.dart
│   ├── telemetry_screen.dart
│   ├── scheduler_screen.dart
│   ├── route_editor_screen.dart
│   ├── task_details_screen.dart
│   ├── settings_screen.dart
│   ├── logs_screen.dart
│   ├── devices_history_screen.dart
│   └── control_guide_screen.dart
│
├── utils/
│   ├── picogo_protocol.dart
│   │   └── JSON command protocol
│   ├── logger.dart
│   │   └── Application logging system
│   └── bluetooth_error_dialog.dart
│       └── Bluetooth error handling
│
└── widgets/
    └── direction_control.dart
        └── Robot movement controls
```

---

# Installation

## Requirements

* Flutter SDK 3.x+
* Android Studio or Visual Studio Code with Flutter extension
* Android device or emulator (API 21+)

> A real Android device is required for Bluetooth functionality.

---

## Clone Repository

```bash
git clone https://github.com/Shef-Kryt/roboctrl-flutter-app.git

cd roboctrl-flutter-app
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Check Flutter Environment

```bash
flutter doctor
```

---

## Run Application

```bash
flutter run
```

---

## Build APK

```bash
flutter build apk --release
```

Generated APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# Communication Protocol

The application communicates with Raspberry Pi Pico using JSON messages.

## Movement Commands

```json
{
  "Forward": "Down"
}

{
  "Forward": "Up"
}

{
  "Left": "Down"
}

{
  "Right": "Up"
}
```

---

## Speed Control Commands

```json
{
  "Low": "Down"
}

{
  "Medium": "Down"
}

{
  "High": "Down"
}
```

---

## LED and Buzzer Control

```json
{
  "LED": "on"
}

{
  "BZ": "off"
}

{
  "RGB": "(255,0,128)"
}
```

---

# User Guide

1. Launch the application.
2. Press **Scan Devices** on the main screen.
3. Select the robot from the available Bluetooth devices.
4. Control movement using joystick or directional buttons.
5. Adjust speed using Low / Medium / High modes.
6. Use navigation sections:

* Sensors — real-time sensor data
* Telemetry — voltage and temperature graphs
* Scheduler — autonomous routes
* Settings — application configuration and themes

---

# Dependencies

| Package                          | Purpose                            |
| -------------------------------- | ---------------------------------- |
| provider                         | State management                   |
| flutter_blue_plus                | Bluetooth Low Energy communication |
| flutter_bluetooth_classic_serial | Bluetooth Classic communication    |
| shared_preferences               | Local settings storage             |
| permission_handler               | Android permissions                |
| flutter_joystick                 | Virtual joystick                   |
| fl_chart                         | Telemetry charts                   |
| path_provider                    | File management                    |
| uuid                             | UUID generation                    |

---

# Known Issues

| Problem                             | Solution                             |
| ----------------------------------- | ------------------------------------ |
| Device is not found during scanning | Enable location services             |
| Bluetooth Classic connection fails  | Pair device in Android settings      |
| BLE commands do not work            | Check Bluetooth UUID characteristics |
| `flutter pub get` error             | Update Flutter SDK                   |

---

# Technologies

* Flutter
* Dart
* Android
* Raspberry Pi Pico (RP2040)
* Bluetooth BLE / SPP
* IoT communication
* JSON protocol
* Material Design 3

---

# My Contribution

* Designed Flutter application architecture
* Developed mobile UI screens and reusable widgets
* Implemented Bluetooth communication layer
* Created robot control interface
* Implemented telemetry visualization
* Added sensor data processing
* Developed application settings system
* Implemented route planning functionality

---

# Screenshots

| Main Screen                                         | Telemetry                                               | Settings                                        |
| --------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------- |
| <img src="screenshots/main_screen.png" width="250"> | <img src="screenshots/settings_screen.png" width="250"> | <img src="screenshots/devices.png" width="250"> |

---

# References

* Flutter Documentation
  https://docs.flutter.dev

* flutter_blue_plus
  https://pub.dev/packages/flutter_blue_plus

* Bluetooth Core Specification
  https://www.bluetooth.com/specifications/

* Material Design 3
  https://m3.material.io

* Raspberry Pi Pico Documentation
  https://www.raspberrypi.com/documentation/microcontrollers/

* Provider State Management
  https://docs.flutter.dev/data-and-backend/state-mgmt/simple

---

## License

MIT License
