# Example script

The project folder has a folder called Examples. The app never reads it, so nothing in it can turn on a device or break the app.

1. README.txt is a short guide for your AI agent. Read it first.
2. Example Turn on script.txt is a complete turn-on script as plain text, with a short explanation above every piece. Copy it, then change the name, the address and the part that sends.
3. Practice device.ps1 is a practice device that talks to nothing and turns nothing on. Its pretend house number is 123.

The example script has six pieces:

1. The switch -Controleer, a dry run that checks everything and sends nothing.
2. The device: its IP address, which gives the house number, and its MAC address.
3. The log: a small function that writes one line when the script is run directly.
4. The question: is the device already on? If yes, send nothing and end with exit code 10.
5. The letter: the message that wakes the device. Then end with exit code 0.
6. The end: write the log line and end with the exit code. An error is logged as failed and ends with exit code 1.

How to practice with Practice device.ps1:

1. Run it in PowerShell. It adds one line to the log with the result test and the source direct, and it ends with exit code 12.
Tip: If PowerShell says scripts are disabled, start it with: powershell -NoProfile -ExecutionPolicy Bypass -File "Examples\Practice device.ps1". That only applies to this one run.
2. Or copy it into the Turn on folder and restart the app. A row appears with house number 123. Press its button: the app shows "Test ran" and writes the log line itself.
3. Want to practice another result? Change the line with $PracticeCode near the top to 0, 10, 11 or 1.
Tip: Remove the copy of Practice device.ps1 from the Turn on folder when you're done.
