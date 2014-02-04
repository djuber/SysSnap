SysSnap
=======

A helpful utility for system performance monitoring and troubleshooting server load issues.

Quick Usage
=======

Quick run of syssnap in screen:
wget -N -P /root https://github.com/echoe/SysSnap/raw/master/sys-snap.sh : chmod +x /root/sys-snap.sh; screen -dmS "monitor" /root/sys-snap.sh

Quick run of the interpreter:
wget -N -P /root https://github.com/echoe/SysSnap/raw/master/ssinterpreter.sh ; chmod +x /root/ssinterpreter.sh ; sh /root/ssinterpreter.sh

General Usage
=======
SysSnap should be used when you want constant logs for the last day on a server. This is generally all of the time, and it doesn't cause much load. In order, this version records:
-top [process information/memory/load]
-mysql usage
-vmstat
-memory information [meminfo]
-ps auxxwf [additional process information]
-netstat [connection information]
-disk space
-either apache or litespeed logs, depending on what is run. It will attempt to take apache logs even if you don't have either litespeed or apache; you'll get a 404 in the logs. This is somewhat by design as I don't have to deal with this personally - you may want to make a small tweak to lines 136-142.
-privvmpages [only if it can; this is only useful on a VPS]

The interpreter uses the added delimiters written at the beginning of each section to grep the specific parts of the logs, collate statistics, and then output them on the command line. It would likely be simpler to write something in python for this, but I feel like a shell script that's self-contained is the easiest solution [speed isn't much of an issue because it only takes one day of logs].
