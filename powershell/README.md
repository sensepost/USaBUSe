There are several payloads here:

Stage 0 - Read Exec
==================

The read_exec's are basically stage0. They open a connection to the binary pipe and read the next stage. They need to be small and stealthy to limit how much time it takes to type them and what a user sees.

Here's a brief description of the various versions:

* read_exec.ps1 - the version you should probably use. It's optimised to be typed quickly, and does clever things to hide the window.

* read_exec_long.ps1 - the same as the above but commented, and indented nicely so you can understand it.

Stage 1
=======

There is one primary Stage 1 option, which is Proxy.ps1. This does a couple of clever things:

* It establishes a TCP proxy, listening on localhost only, on TCP/65535. Any connections to this port will create a new channel (up to 255), which will	be multiplexed over the USB interface to the attacker, where they will be split out into individual connections again.

* It spawns a cmd.exe instance, which is bound to channel 1.

In this way, the attacker gets the opportunity to interact with the victim via cmd.exe, but can also execute other programs connecting back to localhost:65535, in order to upgrade their connection. E.g. one could use this to run a powershell meterpreter upgrade script, or could launch PowerShell Empire, with the "remote server" being at http://localhost:65535/.