# How to connect your device to the log

When the app presses a button, the app writes the log line itself. You don't have to do anything.

When someone runs the script directly in PowerShell, like your AI agent does, the app can't see it. Then the script writes its own line, so the log still tells the whole story.

1. Add a small function to the script that writes one line to Development\logboek.txt. "Example script" shows how.
2. The line has five parts, separated by a Tab: the time like 2026-10-27 16:41:07, the result, the name of the device, the full path of the script and the word direct.
3. The result is one of these words: sent, already-on, not-found, test or failed. It means the same as the exit code: 0 is sent, 10 is already-on, 11 is not-found, 12 is test and anything else is failed.
4. Write the line once, at the very end of the run, when the result is known. Add it to the end of the file in one single write, so two scripts writing at the same moment never lose a line.
5. Skip this when the app runs the script. The app sets the environment variable CREATIVE_CONNECTION to app, so check that first. Otherwise the same run is logged twice.
6. A dry run, which only checks and sends nothing, writes no line.
Tip: If the Development folder isn't there, just skip the line. A problem with the log must never stop the script.
Tip: Never write secret codes, keys or passwords in the line.
