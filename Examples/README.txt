CREATIVE CONNECTION: EXAMPLES FOR YOUR AI AGENT

The app never reads this folder. Nothing here turns on a real device:
the example is only text, and the practice device talks to nothing.

WHAT IS HERE
1. Example Turn on script.txt   A complete turn-on script as text, explained piece by piece.
2. Practice device.ps1          A practice device. It talks to nothing and turns nothing on.

HOW TO USE THEM
1. Read the Help in the app (the "i" at the top), or the files in Development\help,
   from top to bottom.
2. Run "Practice device.ps1" in PowerShell. It adds one line with the result "test"
   to Development\logboek.txt. If PowerShell says scripts are disabled, start it with:
   powershell -NoProfile -ExecutionPolicy Bypass -File "Examples\Practice device.ps1"
   That only applies to this one run.
3. Copy the pieces you need from "Example Turn on script.txt" into a new script for
   the device. Save it outside the Turn on folder and test it there first.
4. When it works, the owner of the computer reads it and says yes. Only then it is saved
   in the Turn on folder, named after the device. An AI agent never adds or changes a
   script there on its own. Close the app and open it again. The device is now a row.

RULES
- Never put secret codes, keys or passwords in a script, a log line or a chat.
- A real device script never ends with exit code 12. That code is only for practice scripts.
- Everything stays on the home network.
- The human has the final say. If they say no, stop.
