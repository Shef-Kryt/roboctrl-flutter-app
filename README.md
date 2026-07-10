# RoboCtrl Flutter App

A cross-platform mobile application for controlling a robotic platform based on Raspberry Pi Pico (RP2040) using Flutter and Dart.

The application provides remote robot control, Bluetooth communication, real-time sensor monitoring, telemetry visualization, and autonomous route management.

## Project Overview

**Project type:** Mobile application (Android)  
**Programming language:** Dart  
**Framework:** Flutter  
**Communication protocols:** Bluetooth Classic (SPP) / Bluetooth Low Energy (BLE)  
**Hardware platform:** Raspberry Pi Pico (RP2040) — PicoGo / Waveshare robotic platform  

## Features

- Bluetooth device scanning and connection (BLE and Classic SPP)
- Robot movement control using virtual joystick and buttons
- Adjustable movement speed
- RGB LED strip control (static colors and animations)
- Real-time sensor monitoring:
  - Battery voltage
  - Temperature
  - Distance sensor
  - Line sensors
- Telemetry dashboard with real-time graphs
- Autonomous route planner with telemetry recording
- Route editor for movement sequences
- Automatic Bluetooth reconnection after connection loss
- Event logging system with file storage
- Application settings management
- Dark and light themes (Material 3)

## Project Architecture
