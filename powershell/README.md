There are several payloads here:

Stage 0 - Read Exec
==================

The read_exec's are basically stage0. They open a connection to the binary pipe and read the next stage. They need to be small and stealthy to limit how much time it takes to type them and what a user sees.

Here's a brief description of the various versions:

* read_exec.ps1 - the version you should probably use. It's optimised to by typed quickly, and does clever things to hide the window.

* read_exec_long.ps1 - the same as the above but indented nicely so you can try understand it.

* read_exec_mini.ps1 - a powershell one liner to be executed via the command line (e.g. cmd.exe). It's smaller than the first read_exec, but can't do smart things to hide the command window while it's being typed.

* read_exec_mini_tab.ps1 - an experiment in seeing if TAB characters could reduce the amount of typing. They didn't really.

Stage 1
=======

There are a couple of stage 1 options:

* spawn.ps1 gives you a simple shell

* screenshot.ps1 takes a screenshot

* msfstage_proxy.ps1 creates the TCP to HID proxy on the host that meterpreter or the like can use

* hello_world.ps1 is a very simple payload with comments to give you a bit of an understanding of the protocol
