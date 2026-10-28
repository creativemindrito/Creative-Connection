# Notes for AI agents

Creative Connection is a small Windows app (PowerShell 5.1 and WinForms) with one
power button per device. A button runs one script from the Turn on folder.

## Read first

1. Read the Help topics in Development\help, from 00 to 15, in order.
2. Look at the Examples folder: a complete example script as text, and a practice
   device that turns nothing on.

## Rules

- Never put a secret in a file, a log or a chat. That means passwords, keys and
  pairing codes.
- Never add or change a script in the Turn on folder until the owner has read it
  and said yes. Build and test it somewhere else first.
- Never guess a pairing code and never log in to the owner's router.
- Run a script only when the owner asks. It can turn on a real device.
- Run the installer only when the owner asks. It adds shortcuts and an entry to
  the list of apps in Windows.

## What you can check yourself

- The app makes no network connections. There is no networking code in
  Creative Connection.ps1.
- The app starts only .ps1 files from the Turn on folder, with Windows PowerShell
  (-ExecutionPolicy Bypass for that one process), and stops a script after
  60 seconds.
- The app writes only inside its own folder (Development\logboek.txt,
  Development\archief\, Development\namen.json) and to the clipboard when you press
  a copy button.

## The two .exe files

Both are built from the code in Development\bouwen with the C# compiler of
.NET Framework 4, which is part of Windows. There is no networking code in either.

- Creative Connection.exe comes from starter.cs. It starts Creative Connection.ps1
  next to it with %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
  -NoProfile -ExecutionPolicy Bypass -File, and nothing else.
- Creative Connection Setup.exe comes from installatie.cs, with every file of the
  release inside it. It is on the Releases page, not in the repository. It installs
  for the current user into %LOCALAPPDATA%\Programs\Creative Connection, without
  admin rights, or into another folder the owner chose. It adds two shortcuts in
  Start, Creative Connection (the app) and Creative Connection folder (its folder),
  and, if chosen, the same two on the desktop, and an entry under
  HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\CreativeConnection.
- To find the app folder, read InstallLocation in that entry. The Turn on folder is
  inside it.
- Removing deletes only the files that are still exactly as installed. Scripts in
  Turn on, the log and the names stay. The uninstaller in the app folder hands the
  work to a copy of itself in the temp folder and ends at once, so the removal
  finishes a moment after its exit code.
- An update goes to the folder that is already installed, unless /dir= says otherwise.
- Options without a window: /quiet, /dir=<folder>, /desktop=none, /startmenu=none,
  /start (open the app afterwards) and /uninstall. Exit code 0 means done, 1 failed,
  2 wrong option, 3 a file is in use (close the app first), 4 the folder is not
  empty and has no Creative Connection in it, 5 not installed.
- To check both files, run Development\bouwen\bouw.ps1 -Check -Setup <the setup
  file>. It builds them again from the code and compares them byte for byte.
  "RESULT: SAME" means they match.

## The contract for a script

Exit code 0 means sent, 10 already on, 11 not found (nothing sent), 12 test
(nothing sent). Anything else means it failed. Outside the app a script writes
one line to the log (Help topic 11).
