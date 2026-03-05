# RootRunner
A Portable Raspberry Pi Handheld You Can Actually Build

No rare parts.  
No long waiting times.  
No supply chain drama.

---

## Why RootRunner?

I wanted something like a uConsole — but without waiting months for hardware and without paying Hackberry Pi CM5 prices for similar performance.

So I built my own version.

The goal was simple:

- Use modern, widely available hardware
- Keep it reproducible
- Avoid exotic or disappearing parts
- Make it serviceable

RootRunner is designed to be built now — and still rebuildable later.

---

## Build Overview

The system is mostly plug & play, but not completely solder-free.

### Minimal soldering required

- Status LED → 220 ohm resistor → wires  
- Sliding power switch soldered into the power line between the power bank and the Raspberry Pi  

No custom PCBs.  
No micro-soldering.  
Basic tools are enough.

Everything else is modular and easy to replace.

---

## Hardware Features

- Sliding cover for USB & LAN access  
- Physical power switch (fully disconnects power)  
- USB-rechargeable battery  
- Integrated keyboard  
- Status LED  

Designed for usability and maintenance — not permanently sealed shut.

---

# Status LED Setup

The status LED is connected as follows:

- **GPIO17 (Physical Pin 11)** → LED (via 220Ω resistor)
- **GND (Physical Pin 6)** → LED ground

You can use standard jumper wires for the connection.

GPIO17 is used because it is stable, well-supported, and easy to configure.

---

## Automatic LED Configuration Script

The project includes a setup script:

`setup-status-led.sh`

### What the script does

- Installs `python3-libgpiod`
- Creates a Python-based LED controller
- Installs and enables a systemd service
- Automatically configures LED behavior:

| System State | LED Behavior |
|--------------|-------------|
| Booting      | Breathing effect |
| Running      | Solid ON |
| Shutdown     | Fast blinking |

### Run the setup

```bash
chmod +x setup-status-led.sh
sudo ./setup-status-led.sh
```

After reboot, the LED will automatically reflect system state.

---

# Kali Linux Docker Container

RootRunner also includes a helper script to install Kali Linux as a persistent Docker container on Raspberry Pi OS.

Script:

`install-kali-container.sh`

---

## What the Kali installer does

- Installs Docker (if missing)
- Pulls `kalilinux/kali-rolling`
- Creates a persistent container
- Grants `NET_RAW` and `NET_ADMIN` capabilities (required for tools like nmap)
- Mounts your home directory to `/host-home`
- Creates convenient host commands:

```
kali
kali-tools
```

---

## Install Kali Container

```bash
chmod +x install-kali-container.sh
./install-kali-container.sh
sudo reboot
```

After reboot:

```bash
kali
kali-tools
```

Example:

```bash
nmap 127.0.0.1
```

Your Raspberry Pi OS home directory is available inside the container at:

```
/host-home
```

---

# Why No Integrated Speakers?

Deliberate choice.

Bluetooth headphones work perfectly and skipping internal speakers makes the system:

- Smaller
- More power efficient
- Less complex
- Easier to maintain

As simple as possible.  
As complex as necessary.

---

# Final Thoughts

RootRunner is not a polished commercial product.

It’s a practical, reproducible, serviceable portable Raspberry Pi system.

You can build it now.  
You can repair it later.  
No rare parts.  
No waiting months.

Just build it.
