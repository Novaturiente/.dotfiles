import os
import shlex
import subprocess

from ranger.api.commands import Command


class kdeconnect_send(Command):
    """:kdeconnect_send

    Send selected files to a device using kdeconnect-cli.
    Skips any selected directories.

    """

    def execute(self):
        # Get first available device id
        result = subprocess.run(
            ["kdeconnect-cli", "-a", "--id-only"],
            capture_output=True,
            text=True,
        )
        device_id = (result.stdout or "").strip().splitlines()[0].strip() if result.returncode == 0 else ""

        if not device_id:
            self.fm.notify("No device found", bad=True)
            return

        # Get full paths of selected files (skip directories)
        paths = []
        for f in self.fm.thistab.get_selection():
            if f.path and not f.is_directory and os.path.isfile(f.path):
                paths.append(f.path)

        if not paths:
            self.fm.notify("No files selected", bad=True)
            return

        paths_s = " ".join(shlex.quote(p) for p in paths)
        command = f"kdeconnect-cli -d {shlex.quote(device_id)} --share {paths_s}"
        self.fm.notify(f"Sending {len(paths)} file(s) to device")
        self.fm.execute_command(command)
        self.fm.thisdir.mark_all(False)
