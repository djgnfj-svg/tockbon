# The godot MCP bridge — only if the server is turned back on

**Right now it is switched OFF** in the machine-local settings file (not in the repo — check the session's
own tool list), so `godot_*` does not exist. **The scripts in `tools/look/` were written under exactly
that condition and are the supported path.** Read this only when the user has re-enabled the server.

The bridge (`127.0.0.1:6550`) accepts **one client**, and `godot_*` is verify-look's alone; everything
else is headless. **`godot_*` screenshots are the one exception to the no-OS-capture rule** — the editor
captures its own viewport and steals no input. ⚠ **Mouse coordinates cannot go through `godot_input`**:
use `tree.root.push_input(ev, true)` inside `godot_exec`.

**Before launching**: is the editor already up · the game window steals focus, so ask whether the user is
working · is there a path for the thing to reach the screen.

## `godot-mcp` (node) survives everything

Agents do not launch it — Claude Code starts it when a session opens, and it does not die when the session
ends. **Measured: no editor running, 6 node processes alive.** ⚠⚠ **The symptom is not "can't grab the
bridge", it is "the user can't see the screen"** — the moment an editor launches they all grab 6550 and
the losers retry forever, flooding the output panel with `Another client is already connected`.

```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'godot' }
```

**More than one: tell the user before launching the editor.** ⚠ **Killing them stays the user's call** —
it also cuts this session's server, and new ones restart immediately (killed 6, 2 came back). **It does
not get clean.**

**Still says `Another client` with no established sockets at all**: the addon is holding a dead client
(`-Force` kills skip the clean close) and no process hunting finds a culprit. ⇒ **Restart the editor.**
As a bonus that also loads the input map if `project.godot` changed.

⚠ **Close any editor you launched when the judgment is done** — otherwise the next session fights over the
bridge and the user is asked to approve the connection again and again. **Especially one holding a
worktree**, which gets cleaned up under it. **An editor the user launched is the exception; if you are not
sure it was yours, ask.**
