//@ pragma UseQApplication
// Self-check for the Nmcli service. Not a daemon — run it by hand after touching
// Nmcli.qml, which is 1800 lines ported wholesale from caelestia-shell:
//
//     qs -p ~/.config/quickshell/quicksettings/selfcheck.qml
//
// It waits for the service to populate, then asserts its view of the world
// matches what `nmcli` itself reports: the radio state, which connection is
// active, and that the network list parsed into something non-empty. Those are
// what break first if the port drifts from upstream's nmcli output parsing.
//
// The visible-SSID sets are printed but not compared: nmcli's scan cache decays
// between calls, so the two sources legitimately disagree moments apart.
//
// Prints one verdict line and quits. Scripted use greps for NMCLI CHECK PASS.
import QtQuick
import Quickshell
import Quickshell.Io
import quicksettings

ShellRoot {
    Item {
        id: root

        property string radio: ""
        property var ssids: []
        property string activeCon: ""
        property int ground: 0

        // Nmcli is a lazily-created singleton: touching it here starts its
        // nmcli calls now, in parallel with the ground-truth ones below, rather
        // than at the moment the assertions read it.
        Component.onCompleted: Nmcli.wifiEnabled

        function report(): void {
            const fails = [];

            if (Nmcli.wifiEnabled !== (radio === "enabled"))
                fails.push(`wifiEnabled is ${Nmcli.wifiEnabled} but nmcli radio wifi says ${radio}`);

            const mine = [...new Set(Nmcli.networks.map(n => n.ssid).filter(s => s))].sort();
            const theirs = [...new Set(ssids)].sort();

            if (theirs.length > 0 && mine.length === 0)
                fails.push("networks list is empty but nmcli sees " + theirs.length);

            if (activeCon && Nmcli.active?.ssid !== activeCon)
                fails.push(`active is ${Nmcli.active?.ssid} but nmcli says ${activeCon}`);

            console.log("radio:    ", radio, "->", Nmcli.wifiEnabled);
            console.log("active:   ", activeCon, "->", Nmcli.active?.ssid ?? "(none)");
            console.log("service:  ", mine.join(", "));
            console.log("nmcli:    ", theirs.join(", "));
            console.log(fails.length === 0 ? "NMCLI CHECK PASS" : "NMCLI CHECK FAIL: " + fails.join(" | "));
            quit.running = true;
        }

        Process {
            running: true
            command: ["nmcli", "-t", "-f", "WIFI", "radio"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.radio = text.trim();
                    root.ground++;
                }
            }
        }

        Process {
            running: true
            command: ["nmcli", "-t", "-f", "SSID", "dev", "wifi", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.ssids = text.split("\n").map(l => l.trim()).filter(l => l);
                    root.ground++;
                }
            }
        }

        Process {
            running: true
            command: ["sh", "-c", "nmcli -t -f NAME,TYPE con show --active | grep wireless | cut -d: -f1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.activeCon = text.trim();
                    root.ground++;
                }
            }
        }

        // Nmcli populates over several async nmcli calls of its own, so give it
        // a moment rather than racing it. The ground-truth commands above run in
        // parallel with the wait.
        Timer {
            running: root.ground === 3
            interval: 6000
            onTriggered: root.report()
        }

        // ponytail: same trick as the common selfcheck — Qt.exit() does not end a
        // Quickshell process, so the check kills its own parent shell.
        Process {
            id: quit

            command: ["sh", "-c", "kill $PPID"]
        }
    }
}
