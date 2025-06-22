WiFi Recon & Deauth Tool (for Alfa AWUS036ACH with Realtek 88XXau)
This script is an educational tool designed to demonstrate the process of putting a Realtek 88XXau-based Wi-Fi adapter (like the Alfa AWUS036ACH) into monitor mode, scanning for wireless networks, and performing a deauthentication attack.

Disclaimer: This tool is for educational purposes ONLY. Using it on networks you do not own or have explicit permission to test is illegal and unethical. The author is not responsible for any misuse.

Table of Contents
Features
Prerequisites
Installation
Usage
How it Works
Troubleshooting
Contributing
License
Features
Automated Driver Loading: Attempts to load the 88XXau kernel module for your Alfa adapter.
Monitor Mode Activation: Utilizes airmon-ng to kill interfering processes and place your wlan0 interface into monitor mode.
Initial Network Scan: Performs a 1-minute airodump-ng scan to list available Wi-Fi networks and help identify your target.
Targeted Network Monitoring: After user input, starts a focused airodump-ng session in a new terminal to capture data (e.g., WPA/WPA2 handshakes) for a specific BSSID and channel.
Continuous Deauthentication: Initiates a continuous deauthentication attack using aireplay-ng against the chosen target.
Robust Error Handling: Includes checks for common issues and provides informative error messages.
Automatic Cleanup: Gracefully brings down monitor mode and restarts NetworkManager upon script interruption (Ctrl+C) or completion.
Prerequisites
Before running this script, ensure you have the following:

A Compatible Wi-Fi Adapter: An Alfa AWUS036ACH or any other adapter using the Realtek 88XXau chipset.
Linux Distribution: Preferably Kali Linux, Parrot OS, or any other Debian-based distribution with aircrack-ng pre-installed.
aircrack-ng Suite: The aircrack-ng suite (which includes airmon-ng, airodump-ng, aireplay-ng) must be installed.
On Debian/Ubuntu/Kali:
Bash

sudo apt update
sudo apt install aircrack-ng
gnome-terminal: The script uses gnome-terminal to open a new window for airodump-ng. If you are using a different desktop environment (KDE, XFCE, etc.), you might need to adjust the gnome-terminal command to your preferred terminal emulator (e.g., konsole, xfce4-terminal).
Sudo Privileges: The script requires sudo for network interface manipulation.
Installation
Save the script:
Create a new file, for example, wifi_tool.sh, and paste the script content into it.

Bash

nano wifi_tool.sh
(Paste the script, then Ctrl+O, Enter, Ctrl+X)

Make it executable:

Bash

chmod +x wifi_tool.sh
Usage
Connect your Alfa adapter.
Run the script with sudo:
Bash

sudo ./wifi_tool.sh
Observe the initial scan: The script will run airodump-ng for 1 minute, displaying all detected Wi-Fi networks.
Identify your target: From the airodump-ng output, note down the BSSID (MAC address) and Channel of the network you intend to target (for educational purposes, this should be your own network).
Enter BSSID and Channel: After 1 minute, the script will prompt you to enter the BSSID and Channel.
Monitor the new terminal: A new gnome-terminal window will open, running airodump-ng specifically targeting the chosen network. This window is crucial for capturing the WPA/WPA2 4-way handshake if a client connects or re-authenticates.
Deauthentication in progress: In the original terminal, aireplay-ng will begin sending deauthentication packets.
To stop: Press Ctrl+C in the terminal where you initially ran the script. The script will automatically clean up by bringing down the monitor interface and restarting NetworkManager.
How it Works
modprobe 88XXau: Loads the necessary driver for the Realtek 88XXau chipset.
airmon-ng check kill: Identifies and terminates processes that might interfere with monitor mode (e.g., NetworkManager, wpa_supplicant).
airmon-ng start wlan0: Puts your wlan0 interface into monitor mode, often creating a new virtual interface like wlan0mon or mon0. The script attempts to automatically detect this new name.
airodump-ng [monitor_interface]: Scans for Wi-Fi networks, displaying BSSIDs, SSIDs, channels, encryption types, and connected clients.
airodump-ng -c <channel> --bssid <bssid> -w captures [monitor_interface]: Focuses on a single network, captures all packets on its channel, and saves them to .cap files (e.g., captures-01.cap). These capture files are essential for cracking WPA/WPA2 passwords later.
aireplay-ng --deauth 0 -a <bssid> [monitor_interface]: Sends a continuous stream of deauthentication packets to the target BSSID. This forces connected clients to disconnect and then reauthenticate, which can help in capturing the WPA/WPA2 handshake if airodump-ng is actively monitoring.
trap command: Ensures proper cleanup (taking down the monitor interface, restarting NetworkManager) even if the script is interrupted.
Troubleshooting
"wlan0 not found":
Ensure your adapter is physically connected.
Check if the 88XXau module loaded successfully.
Run ip a to see if wlan0 exists.
"Failed to load 88XXau module":
Make sure you have the correct drivers installed for your specific adapter. Sometimes, compiling from source is necessary.
Check your kernel version compatibility.
"Failed to put wlan0 into monitor mode":
Confirm aircrack-ng is installed correctly.
There might be other services interfering; try running sudo systemctl stop NetworkManager before the script (though airmon-ng check kill should handle this).
Some virtual machines or older hardware might have issues with proper passthrough or driver support.
Monitor Interface Name Issue (wlan0mon, mon0, etc.):
The script attempts to automatically detect the new monitor interface name (e.g., wlan0mon, mon0) created by airmon-ng.
If you consistently face issues or the script defaults to wlan0mon but your system uses a different name, you can manually verify the name after airmon-ng start wlan0 by running iw dev or ip a.
If necessary, you can hardcode the MONITOR_INTERFACE variable early in the script, for example: MONITOR_INTERFACE="wlan0mon" if that's the consistent name on your system.
gnome-terminal not opening:
If you're not using GNOME, replace gnome-terminal with your terminal emulator's command (e.g., konsole, xfce4-terminal, xterm).
Ensure the gnome-terminal package is installed: sudo apt install gnome-terminal.
No handshake captured:
Ensure airodump-ng is running in the new terminal correctly.
Make sure there are active clients on the target network. The deauthentication attack needs clients to force them to reauthenticate.
You might need to wait longer or try multiple deauth attempts.
Contributing
Feel free to open issues or submit pull requests if you have suggestions for improvements, bug fixes, or new features.

License
This project is licensed under the MIT License - see the LICENSE file for details.

