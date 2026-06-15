#!/usr/bin/env bash
set -euo pipefail

CAM_ID="13d3:52b9"
XHCI="0000:c4:00.4"

echo "[1/3] Resetting internal webcam USB controller ($XHCI)..."
sudo sh -c "echo $XHCI > /sys/bus/pci/drivers/xhci_hcd/unbind"
sleep 2
sudo sh -c "echo $XHCI > /sys/bus/pci/drivers/xhci_hcd/bind"
sleep 3

echo "[2/3] Checking webcam/video devices..."
lsusb | grep -iE "$CAM_ID|webcam" || true
ls -l /dev/video* 2>/dev/null || true
v4l2-ctl --list-devices 2>/dev/null || true

echo "[3/3] Installing udev rule to keep webcam USB power on (prevents resume disconnect bug)..."
sudo tee /etc/udev/rules.d/99-asus-webcam-power.rules >/dev/null <<'RULE'
# ASUS FHD webcam (Azurewave 13d3:52b9): avoid USB runtime PM resume -22 disconnects
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3", ATTR{idProduct}=="52b9", TEST=="power/control", ATTR{power/control}="on"
RULE
sudo udevadm control --reload-rules
sudo udevadm trigger -s usb || true

echo "Done. If /dev/video* is still missing, reboot once with the new rule installed."
