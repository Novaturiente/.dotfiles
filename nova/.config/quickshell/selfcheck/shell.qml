//@ pragma UseQApplication
// Self-check for the shared `common` module. Not a daemon — run it by hand after
// touching Tokens.qml, Anim.qml or any of the Styled* types:
//
//     qs -c selfcheck
//
// It prints every Anim preset's resolved duration and curve, asserts they match
// caelestia-shell's tokens.hpp, instantiates each ported type, then prints one
// verdict line and quits. Scripted use greps for SELFCHECK PASS.
import Quickshell
import Quickshell.Io
import QtQuick
import common

ShellRoot {
    Item {
        Component.onCompleted: {
            const names = ["StandardSmall", "Standard", "StandardLarge", "StandardExtraLarge",
                           "EmphasizedSmall", "Emphasized", "EmphasizedLarge", "EmphasizedExtraLarge",
                           "FastSpatial", "DefaultSpatial", "SlowSpatial",
                           "FastEffects", "DefaultEffects", "SlowEffects"];
            // Durations upstream defines for each preset, in enum order.
            const expected = [200, 400, 600, 1000, 200, 400, 600, 1000, 350, 500, 650, 150, 200, 300];

            let fails = [];
            for (let i = 0; i < names.length; i++) {
                const a = Qt.createQmlObject('import common; Anim { type: ' + i + ' }', this);
                const c = a.easing.bezierCurve;
                if (a.duration !== expected[i])
                    fails.push(names[i] + ": duration " + a.duration + " != " + expected[i]);
                // A bezier curve is whole cubic segments and has to land on (1, 1).
                if (c.length % 6 !== 0)
                    fails.push(names[i] + ": curve length " + c.length + " is not a whole number of segments");
                if (c[c.length - 1] !== 1 || c[c.length - 2] !== 1)
                    fails.push(names[i] + ": curve does not end at (1, 1)");
                console.log(names[i], a.duration + "ms", "[" + c.map(n => n.toFixed(2)).join(", ") + "]");
            }

            // Emphasized is the one preset built from two cubic segments.
            const emph = Qt.createQmlObject('import common; Anim { type: Anim.Emphasized }', this);
            if (emph.easing.bezierCurve.length !== 12)
                fails.push("Emphasized should be two cubic segments, got " + emph.easing.bezierCurve.length / 6);

            // Every ported type must at least build against the current Qt.
            Qt.createQmlObject('import common; CAnim {}', this);
            Qt.createQmlObject('import common; StyledRect {}', this);
            Qt.createQmlObject('import common; StyledTextField {}', this);
            Qt.createQmlObject('import common; import QtQuick; Item { StateLayer {} }', this);
            Qt.createQmlObject('import common; import QtQuick; Item { ListView { id: l } StyledScrollBar { flickable: l } }', this);

            console.log(fails.length === 0 ? "SELFCHECK PASS" : "SELFCHECK FAIL: " + fails.join(" | "));
            quit.running = true;
        }

        // ponytail: Qt.exit() does not end a Quickshell process, so the check stops
        // itself. $PPID inside sh is this qs process.
        Process {
            id: quit

            command: ["sh", "-c", "kill $PPID"]
        }
    }
}
