# Step by step: add a new device

1. Give the device a house number. Read "Give your device a house number".
2. Find out which letter it understands. Read "Can I connect my device?" and "For your AI agent: how to find out".
3. Make a practice script outside the app, for example on your desktop. Don't put it in the Turn on folder yet.
4. Give the script a dry run that checks everything but sends nothing.
5. Put the device's IP address in the script, so the app can show its house number.
6. Make the script end with one clear exit code: 0 means sent, 10 means already on, 11 means the device wasn't found. For a device that can be woken up, a wake-up message may have been sent, but never the power button. Anything else means it failed.
7. Run the practice script in PowerShell, or let your AI agent run it. First the dry run, then for real.
8. Only when it works, move it into the Turn on folder and name it after the device, like "TV.ps1".
Tip: Give every device a clear name with the room or the owner, like "TV bedroom" or "PS5 Sam". That way you and your AI agent always know which device is meant.
9. Restart the app. The device appears as a new row with its house number. Press the button once and check the log.
Tip: Testing outside the app first means a broken script can never break the app.
