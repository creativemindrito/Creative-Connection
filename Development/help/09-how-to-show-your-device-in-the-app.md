# How to show your device in the app

Every device in the app is one script in the Turn on folder. Put a script there and the device gets its own row.

1. Write one PowerShell script for the device. One device is one script.
2. Save it in the Turn on folder, next to the app. The file name is the name in the app, without ".ps1", like "TV bedroom.ps1". The rows are sorted by file name.
3. Write the device's IP address in the script as plain text, like '192.0.2.50'. The first IP address in the script gives the house number: the last number of that address.
Tip: The app skips addresses that start with 0, 127 or 255, or end with 0 or 255.
4. Optional: add a picture. Save a white PNG in the folder Development\iconen\apparaten and name it after the first word of the script name, in small letters, like tv.png for "TV bedroom.ps1". Without a picture the row shows a plug.
5. Close the app and open it again. The app reads the Turn on folder once, when it starts. It doesn't refresh by itself, so a new script shows up after a restart.
6. Press the new button once. Then open the log, the book at the top right, and check what happened.
Tip: The pencil next to a name lets you give the row your own name. The file name stays the same.
Tip: Every .ps1 file in the Turn on folder becomes a button. Never leave copies or backups there.
