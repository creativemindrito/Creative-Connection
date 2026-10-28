# Examples

Every device is different, but you're not starting from scratch. Here are two real examples that worked. The TV took a lot more puzzling than the PS5, so don't give up if yours is stubborn too.

The PS5

This is how we connected our own PS5. It was a hard one.

1. The PS5 does not understand Wake-on-LAN. It only wakes up for a letter in Sony's own language, with a secret code inside.
2. Sony's own Remote Play app can wake the PS5, but you can't run it from a script or look inside its code.
3. So we used chiaki-ng, a free open source Remote Play program. Because its code is open, we could see how it wakes the PS5.
4. We paired the PS5 once with chiaki-ng. It keeps the code in its settings on this PC, under your Windows account.
5. Our script reads that code at the moment it runs. The code is never written in the script and never shown on screen.
6. First the script calls out "PS5, where are you?". A PS5 that is on answers 200. A PS5 in rest mode answers 620.
7. Only when our own PS5 answers does the script send the wake-up letter, twice, a moment apart.
8. In the router we gave the PS5 a fixed house number. We used the MAC address of the cable, because that is the one the router was using.
Tip: You still log in to PlayStation Network yourself. The script only wakes the PS5.

A Hisense TV

1. Give the TV a house number (its address on your network).
2. Check that your computer can find the TV while it's on.
3. Find out how the official remote app talks to the TV.
4. Look for an open source project that already speaks that language.
5. Pair once: the TV shows a code on screen and you type it in yourself.
6. Keep the keys safe on your own computer, never in the script.
7. Test first with a check that sends nothing, then try the real button.

What we ran into along the way:

The power button is a switch. Pressing it twice quickly turns the TV straight back off. We added a short cooldown, so a second press is blocked for 30 seconds.

The TV doesn't answer a simple ping, whether it is on or off. So a ping can't tell you if it's on. We ask the TV itself instead.

The TV can repeat an old status. Right after it wakes up, it may still report what it said before, like "asleep". Don't trust that first message blindly.

Deep sleep: after about 20 minutes in standby, the TV disappears from the network completely. The button can't reach it anymore. Our fix: the script sends a wake-up message first (Wake-on-LAN). On this TV, that wake-up message turned it fully on by itself.

Turn on only turns on. If the TV is already on, the button does nothing, so it won't switch your TV off by accident.

The lesson: start simple, test every step, and when something strange happens, write it down. Every surprise brings you closer to a button that just works.
