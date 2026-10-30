# macOS debugger ownership follow-up

Source review only. No Cocoa compile or native macOS execution was available.
The Linux ownership repair does not repair or validate either Cocoa path.

- `source/hbbuilder_macos.prg`, `TBDebugRun`: both normal Debug and Debug to
  Breakpoint call `IDE_DEBUGRUNTOBREAK2` unconditionally. This bridge launches
  through `system()` with a background shell command. Its normal cleanup closes
  sockets but does not own or stop the launched process. Accept failure also
  closes sockets without owned-process cleanup.
- `source/backends/cocoa/cocoa_editor.mm`, `IDE_DEBUGSTART2`: this exported bridge
  also launches through a background shell command. Its final cleanup calls
  `killall DebugApp`. That can target unrelated same-name processes, but this
  source review does not establish a native reproduction. The current macOS UI
  path above does not call this bridge. It remains declared EXTERNAL.

The build targets macOS 10.15 with ARC and C++17. A later repair must cover both
bridges without assuming the Linux child/reaping design transfers to Cocoa.
Keep process ownership, launch errors, already-exited children, stop, accept
failure, and bounded cleanup under native tests using only test-owned processes.
Do not ask someone to reproduce the name-based termination on real work.
No Cocoa changes or claims of a fixed macOS port accompany this note.
