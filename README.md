# TinkerDistro

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Community Chat](https://img.shields.io/badge/Discord-Join%20Chat-blue)](https://discord.gg/example)

**Yocto-based Embedded OS with Reliable OTA Updates**

TinkerDistro offers two specialized profiles for IoT deployments:
- 🖥️ **Kiosk Image** (300MB) with Chromium browser
- 📡 **Sensors Image** (200MB) for embedded sensing

---

## 🧩 Image Profiles

| Feature| Sensors Image (200MB) | Kiosk Image (300MB)|
|----------------------|----------------------------|------------------------------|
| Base System| Read-only rootfs | Read-only rootfs |
| Includes | Python 3, MQTT, GPIO tools | Chromium (Ozone/Wayland) |
| Networking | CoAP/MQTT support| WebSocket enabled|
| UI | Headless | Kiosk-mode browser |
| Hardware Acceleration| Basic I²C/SPI| OpenGL ES, touchscreen |

---

## 🚀 Key Features

- **RAUC OTA Updates**: Atomic A/B updates with rollback protection
- **Immutable Core**: Read-only root filesystem by default
- **Dual Profiles**: Optimized for both sensing and display use cases
- **Yocto Foundation**: Reproducible builds with OpenEmbedded
- **Compact Sizes**: 200MB (sensors) / 300MB (kiosk) base images

---

## 🔨 Build from Source

Setup Environment
```bash
source poky/oe-init-build-env build
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-raspberrypi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-openembedded/meta-networking
bitbake-layers add-layer ../meta-openembedded/meta-webserver
bitbake-layers add-layer ../meta-rauc
bitbake-layers add-layer ../meta-rauc-community/meta-rauc-raspberrypi
bitbake-layers add-layer ../meta-tinker
bitbake-layers add-layer ../meta-clang
bitbake-layers add-layer ../meta-browser/meta-chromium
```

Create example keys 
```bash
source poky/oe-init-build-env build
../meta-rauc-community/create-example-keys.sh || true
```
 
Build HomeSensorHub sensors image
```bash
source poky/oe-init-build-env build
export MACHINE=raspberrypi0-wifi
export DISTRO=poky-tinker
bitbake homesensorhub-image homesensorhub-bundle
```
Build ControlCenter kiosk image
```bash
source poky/oe-init-build-env build
export MACHINE=raspberrypi-armv8
export DISTRO=poky-tinker-gui
bitbake controlcenter-image controlcenter-bundle
```

## 📥 Flashing

HomeSensorHub image:
```bash
sudo bmaptool copy build/tmp/deploy/images/raspberrypi0-wifi/homesensorhub-image-raspberrypi0-wifi.rootfs.wic.bz2 /dev/sdX

```
ControlCenter kiosk image:
```bash
sudo bmaptool copy build/tmp/deploy/images/raspberrypi-armv8/controlcenter-image-raspberrypi-armv8.rootfs.wic.bz2 /dev/sdX

```

## 🔄 RAUC Update System
Diagram
Code

Basic OTA Commands:
```bash
# Check update status
rauc status

# Install bundle HomeSensorHub
rauc install http://example.com/homesensorhub-bundle-raspberrypi0-wifi.raucb

# Install bundle Control Center
rauc install http://example.com/controlcenter-bundle-raspberrypi-armv8.raucb
```