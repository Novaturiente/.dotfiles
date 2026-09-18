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

            // The Material 3 widgets added for the quicksettings panels.
            Qt.createQmlObject('import common; StyledText {}', this);
            Qt.createQmlObject('import common; MaterialIcon { text: "wifi" }', this);
            Qt.createQmlObject('import common; StyledSwitch {}', this);
            Qt.createQmlObject('import common; StyledSlider {}', this);
            Qt.createQmlObject('import common; StyledRadioButton {}', this);
            Qt.createQmlObject('import common; TextButton { text: "x" }', this);
            Qt.createQmlObject('import common; IconTextButton { icon: "settings"; text: "x" }', this);
            Qt.createQmlObject('import common; CircularIndicator {}', this);
            Qt.createQmlObject('import common; CustomMouseArea {}', this);
            Qt.createQmlObject('import common; AnchorAnim {}', this);

            // The font builder has to hand back a fresh object each call, or one
            // call site's weight would leak into every other user of the token.
            const base = Tokens.font.body.builders.medium;
            const bold = base.weight(Font.Medium).build();
            const plain = base.build();
            if (bold.weight === plain.weight)
                fails.push("font builder: .weight() did not take effect");
            if (plain.weight !== Font.Normal)
                fails.push("font builder: .weight() leaked back into the shared token");
            if (base.scale(2).build().pointSize !== plain.pointSize * 2)
                fails.push("font builder: .scale(2) did not double the point size");

            // Every Material 3 role the ported panels name must exist. An
            // undefined role reads as the colour black and is easy to miss.
            for (const role of ["m3onSurface", "m3onSurfaceVariant", "m3outline", "m3primary",
                                "m3onPrimary", "m3primaryContainer", "m3onPrimaryContainer",
                                "m3secondaryContainer", "m3onSecondaryContainer", "m3error",
                                "m3onError", "m3surface", "m3surfaceContainer",
                                "m3surfaceContainerHighest", "m3secondary", "m3onSecondary"])
                if (Colors[role] === undefined)
                    fails.push("Colors." + role + " is missing from the theme template");

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
