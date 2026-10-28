# How the log works

The log is the memory of the app. Every time a script runs, one line is added to the file logboek.txt in the Development folder. The book at the top right shows the same lines.

The file is plain text: one line per run, the newest at the bottom. Nothing is ever deleted. When the file gets bigger than 512 KB, the app moves it to the folder Development\archief and starts a new one.

A line has these parts, separated by a Tab: the time, the result, the name, the path of the script and the source. Lines written by the app add four more: the exit code, the seconds the script took, a short code for the version of the script and the time in UTC.

The result is one short word: sent, already-on, not-found, test, exit N (the script ended with number N), timeout (the script took longer than 60 seconds and was stopped) or failed (the script couldn't run). The source is app when the app pressed the button, and direct when someone ran the script in PowerShell.

A script tells the app what happened with its exit code. The number in front is the code:

0. Sent. The script sent its turn-on message.
10. Already on. Nothing was sent.
11. Not found. The device didn't answer and nothing was sent. For a device that can be woken up, a wake-up message may have been sent, but never the power button.
12. Test. A practice script ran. Nothing was turned on and nothing was sent. A real device script never gives 12.
1. Failed. The script stopped with an error. Any other number means failed too.

How your AI agent reads the log:

1. Open Development\logboek.txt as text and read the last lines first. They are the newest.
2. Need older lines? Look in the folder Development\archief. The newest file there has the latest date in its name.
3. Never change or delete lines in the log.

How you copy the log:

1. Click the book at the top right to open the log.
2. The copy button at the top copies all the lines you see, with a short explanation of the codes. Paste it in a chat with your AI agent. The small copy button at the top right of a block copies only that line.
3. In the copy, the result is always one of sent, already-on, not-found, test, failed or timeout. Every other exit code shows as failed, with its number next to it.
4. The log shows the last 10 lines. "Show more" at the bottom adds 10 older ones. The buttons All, On and Problems filter the lines, and the numbers on them count every line.
Tip: The log shows the full path of each script and the names of your devices, but never secret codes. Check it before you share it with someone you don't know.
