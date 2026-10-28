# Security

Creative Connection starts scripts on your own computer, so a flaw in the app can
matter.

## Report a problem

Report it privately, not as a public issue: open the Security tab of this project
on GitHub and choose "Report a vulnerability". Say what you did, what happened and
what you expected. Do not send secrets.

## What counts

- The app starts something other than a .ps1 file from the Turn on folder.
- The app writes outside its own folder, or makes a network connection.
- A Help file or an icon runs code.
- A script starts without anyone pressing a button.

## What does not count

A script you put in the Turn on folder runs with your own rights. Read it first.
