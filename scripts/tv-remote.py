#!/usr/bin/env python3
"""Publishes the Xiaomi TV as an MPRIS player (org.mpris.MediaPlayer2.tv) so the island and
playerctl can show and control it, and keeps adb connected to the TV. Run by tv-remote.service.
Keyboard remote mode (Mod+Alt+Space) lives in hypr/binds.lua and needs the adb connection kept here.
TV_MPRIS=0 keeps only the adb connection (novarch: novahome publishes the player, so the phone
gets one card via KDE Connect). Self-check: tv-remote.py --selftest"""
import os
import re
import subprocess
import sys
import threading
import time

TV = os.environ.get("TV_ADDR", "192.168.220.102:5555")
APPS = {
    "com.netflix.ninja": "Netflix",
    "org.smarttube.stable": "SmartTube",
    "com.google.android.youtube.tv": "YouTube",
    "in.startv.hotstartv": "JioHotstar",
    "com.amazon.amazonvideo.livingroom": "Prime Video",
}
PROBE = ('dumpsys audio | grep -c "state:started attr:AudioAttributes: usage=USAGE_MEDIA"; '
         'dumpsys window | grep -m1 mCurrentFocus')
# Next/Previous seek instead of skipping: on a TV that is the useful action.
KEYS = {"PlayPause": "KEYCODE_MEDIA_PLAY_PAUSE", "Play": "KEYCODE_MEDIA_PLAY",
        "Pause": "KEYCODE_MEDIA_PAUSE", "Stop": "KEYCODE_MEDIA_STOP",
        "Next": "KEYCODE_MEDIA_FAST_FORWARD", "Previous": "KEYCODE_MEDIA_REWIND"}


def parse(out):
    """Probe output -> (PlaybackStatus, title). An empty title hides the TV in the island."""
    first = out.split("\n", 1)[0].strip()
    playing = first.isdigit() and int(first) > 0
    m = re.search(r" u0 ([\w.]+)/", out)
    title = APPS.get(m.group(1), "") if m else ""
    if playing:
        return "Playing", title or "TV"
    return ("Paused", title) if title else ("Stopped", "")


def adb(*args, timeout=6):
    try:
        r = subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout
    except subprocess.TimeoutExpired:
        return 1, ""


def ensure_connected():
    """True when the TV is usable. Leaves 'unauthorized' alone so the TV's Allow prompt stays open."""
    _, out = adb("devices")
    state = next((l.split()[1] for l in out.splitlines()[1:] if l.split()[:1] == [TV]), "")
    if state == "device":
        return True
    if state != "unauthorized":
        adb("disconnect", TV)  # a rebooted TV leaves a stale 'offline' entry
        adb("connect", TV)
    return False


def selftest():
    focus = "  mCurrentFocus=Window{494f126 u0 %s/x.MainActivity}"
    assert parse("1\n" + focus % "com.netflix.ninja") == ("Playing", "Netflix")
    assert parse("0\n" + focus % "org.smarttube.stable") == ("Paused", "SmartTube")
    assert parse("0\n" + focus % "com.nova.tvhome") == ("Stopped", "")
    assert parse("2\n" + focus % "com.nova.tvhome") == ("Playing", "TV")
    assert parse("") == ("Stopped", "")
    print("selftest ok")


def main():
    if os.environ.get("TV_MPRIS") == "0":
        delay = 5
        while True:
            # back off while the TV is away (5s doubling to 5min), reset once connected
            if ensure_connected():
                delay = 5
                time.sleep(5)
            else:
                time.sleep(delay)
                delay = min(delay * 2, 300)
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib

    ROOT, PLAYER, PROPS = "org.mpris.MediaPlayer2", "org.mpris.MediaPlayer2.Player", "org.freedesktop.DBus.Properties"

    class Tv(dbus.service.Object):
        def __init__(self, bus):
            super().__init__(bus, "/org/mpris/MediaPlayer2")
            self.status, self.title = "Stopped", ""
            self.wake = threading.Event()

        def props(self, iface):
            if iface == ROOT:
                return {"Identity": "TV", "CanQuit": False, "CanRaise": False, "HasTrackList": False,
                        "SupportedUriSchemes": dbus.Array([], "s"), "SupportedMimeTypes": dbus.Array([], "s")}
            if iface == PLAYER:
                meta = {"mpris:trackid": dbus.ObjectPath("/org/mpris/MediaPlayer2/tv/track")}
                if self.title:
                    meta.update({"xesam:title": self.title, "xesam:artist": dbus.Array(["TV"], "s")})
                return {"PlaybackStatus": self.status, "Metadata": dbus.Dictionary(meta, "sv"),
                        "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0, "Volume": 1.0,
                        "Position": dbus.Int64(0), "CanControl": True, "CanPlay": True, "CanPause": True,
                        "CanGoNext": True, "CanGoPrevious": True, "CanSeek": False}
            return {}

        @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
        def Get(self, iface, name):
            return self.props(iface)[name]

        @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
        def GetAll(self, iface):
            return self.props(iface)

        @dbus.service.method(PROPS, in_signature="ssv")
        def Set(self, iface, name, value):
            pass  # Volume/Rate are fixed; TV volume goes through the keyboard remote mode

        @dbus.service.signal(PROPS, signature="sa{sv}as")
        def PropertiesChanged(self, iface, changed, invalidated):
            pass

        @dbus.service.method(ROOT)
        def Raise(self):
            pass

        @dbus.service.method(ROOT)
        def Quit(self):
            pass

        def key(self, method):
            subprocess.Popen(["adb", "-s", TV, "shell", "input", "keyevent", KEYS[method]])
            self.wake.set()  # re-probe soon so the island follows the change

        @dbus.service.method(PLAYER)
        def PlayPause(self): self.key("PlayPause")

        @dbus.service.method(PLAYER)
        def Play(self): self.key("Play")

        @dbus.service.method(PLAYER)
        def Pause(self): self.key("Pause")

        @dbus.service.method(PLAYER)
        def Stop(self): self.key("Stop")

        @dbus.service.method(PLAYER)
        def Next(self): self.key("Next")

        @dbus.service.method(PLAYER)
        def Previous(self): self.key("Previous")

        @dbus.service.method(PLAYER, in_signature="x")
        def Seek(self, offset): pass

        @dbus.service.method(PLAYER, in_signature="ox")
        def SetPosition(self, track, position): pass

        @dbus.service.method(PLAYER, in_signature="s")
        def OpenUri(self, uri): pass

        def update(self, status, title):
            if (status, title) != (self.status, self.title):
                self.status, self.title = status, title
                p = self.props(PLAYER)
                self.PropertiesChanged(PLAYER, {"PlaybackStatus": p["PlaybackStatus"], "Metadata": p["Metadata"]}, [])
            return False

        def poll(self):
            while True:
                state = ("Stopped", "")
                if ensure_connected():
                    code, out = adb("-s", TV, "shell", PROBE)
                    if code == 0:
                        state = parse(out)
                GLib.idle_add(self.update, *state)
                if self.wake.wait(3):
                    self.wake.clear()
                    time.sleep(1)  # let the app act on the key before probing

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.mpris.MediaPlayer2.tv", bus)  # noqa: F841 (keeps the name owned)
    tv = Tv(bus)
    threading.Thread(target=tv.poll, daemon=True).start()
    GLib.MainLoop().run()


if __name__ == "__main__":
    selftest() if sys.argv[1:] == ["--selftest"] else main()
