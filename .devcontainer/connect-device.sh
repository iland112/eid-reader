#!/bin/bash
# ADB TCP/IP connection helper for DevContainer
#
# Usage:
#   1. On Windows host: Connect Android device via USB
#   2. On Windows PowerShell: adb tcpip 5555
#   3. Find device IP: adb shell ip route | awk '{print $9}'
#   4. In DevContainer: ./connect-device.sh <device-ip>

DEVICE_IP=${1:?"Usage: $0 <device-ip>"}

echo "Connecting to Android device at ${DEVICE_IP}:5555..."
adb connect "${DEVICE_IP}:5555"

echo ""
echo "=== Connected devices ==="
adb devices

echo ""
echo "=== Flutter devices ==="
flutter devices
