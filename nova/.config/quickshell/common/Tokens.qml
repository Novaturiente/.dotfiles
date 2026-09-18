// Material 3 Expressive motion and shape tokens.
//
// Ported by hand from caelestia-shell's C++ config plugin
// (plugin/src/Caelestia/Config/tokens.hpp) so the values live in plain QML and
// need no compiled dependency. Hand-written — unlike Colors.qml, scripts/theme.sh
// does not touch this file.
//
// Curves are cubic-bezier control-point lists in the form QML's
// `easing.bezierCurve` wants: triples of (x, y) ending at (1, 1). `emphasized`
// carries two cubic segments, hence twelve numbers.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property var anim: ({
        curves: {
            emphasized:               [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1],
            emphasizedAccel:          [0.3, 0, 0.8, 0.15, 1, 1],
            emphasizedDecel:          [0.05, 0.7, 0.1, 1, 1, 1],
            standard:                 [0.2, 0, 0, 1, 1, 1],
            standardAccel:            [0.3, 0, 1, 1, 1, 1],
            standardDecel:            [0, 0, 0, 1, 1, 1],
            expressiveFastSpatial:    [0.42, 1.67, 0.21, 0.9, 1, 1],
            expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1],
            expressiveSlowSpatial:    [0.39, 1.29, 0.35, 0.98, 1, 1],
            expressiveFastEffects:    [0.31, 0.94, 0.34, 1, 1, 1],
            expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1],
            expressiveSlowEffects:    [0.34, 0.88, 0.34, 1, 1, 1]
        },
        durations: {
            small: 200,
            normal: 400,
            large: 600,
            extraLarge: 1000,
            expressiveFastSpatial: 350,
            expressiveDefaultSpatial: 500,
            expressiveSlowSpatial: 650,
            expressiveFastEffects: 150,
            expressiveDefaultEffects: 200,
            expressiveSlowEffects: 300
        }
    })

    // ponytail: `full` is INT_MAX upstream; Rectangle clamps radius to half the
    // shorter side anyway, so any number past the largest menu works.
    readonly property var rounding: ({
        extraSmall: 4, small: 8, medium: 12, large: 16, largeIncreased: 20,
        extraLarge: 28, extraLargeIncreased: 32, extraExtraLarge: 48, full: 9999
    })

    readonly property var spacing: ({
        extraSmall: 4, small: 8, medium: 12, large: 16, largeIncreased: 20,
        extraLarge: 28, extraLargeIncreased: 32, extraExtraLarge: 48
    })

    readonly property var padding: ({
        extraSmall: 4, small: 8, medium: 12, large: 16, largeIncreased: 20,
        extraLarge: 28, extraLargeIncreased: 32, extraExtraLarge: 48
    })

    readonly property var fontSize: ({
        small: 11, smaller: 12, normal: 13, larger: 15, large: 18, extraLarge: 28
    })

    // ---- Fonts -------------------------------------------------------------
    // Material 3 type scale. Point sizes come from caelestia's
    // plugin/src/Caelestia/Config/appearanceconfig.hpp; the families are this
    // repo's, not caelestia's (it ships GoogleSansFlex and CaskaydiaCove NF).
    readonly property string sansFamily: "JetBrainsMono Nerd Font"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFamily: "Material Symbols Rounded"

    // Returns a chainable font builder. Every call returns a NEW builder, so a
    // shared token like `Tokens.font.body.builders.medium` can never be mutated
    // by one call site and leak into another.
    //
    // ponytail: replaces caelestia's C++ FontBuilder. Only the four methods the
    // panels actually call are here; variable axes are set directly on
    // MaterialIcon instead, which is the only thing that needs them.
    function fontBuilder(spec) {
        return {
            weight: w => fontBuilder(Object.assign({}, spec, { weight: w })),
            size: s => fontBuilder(Object.assign({}, spec, { pointSize: s })),
            scale: s => fontBuilder(Object.assign({}, spec, { pointSize: Math.round(spec.pointSize * s) })),
            build: () => Qt.font(spec)
        };
    }

    function fontStyle(family, sizes, weight) {
        const style = { builders: {} };
        for (const name in sizes) {
            const spec = { family: family, pointSize: sizes[name], weight: weight };
            style[name] = Qt.font(spec);
            style.builders[name] = fontBuilder(spec);
        }
        return style;
    }

    readonly property var font: ({
        body: fontStyle(sansFamily, { small: 12, medium: 14, large: 16 }, Font.Normal),
        title: fontStyle(sansFamily, { small: 14, medium: 16, large: 22 }, Font.Medium),
        label: fontStyle(sansFamily, { small: 11, medium: 12, large: 14 }, Font.Medium),
        mono: fontStyle(monoFamily, { small: 12, medium: 14, large: 16 }, Font.Normal),
        // Icon sizes are caelestia's dp values divided by 1.33, as in the header.
        icon: Object.assign(fontStyle(iconFamily, { small: 15, medium: 18, large: 24, extraLarge: 36 }, Font.Normal), {
            size: s => fontBuilder({ family: iconFamily, pointSize: s, weight: Font.Normal })
        })
    })

    // ---- Sizes -------------------------------------------------------------
    // Panel widths, from caelestia's BarTokens. Only the ones the quicksettings
    // panels reference are kept.
    readonly property var sizes: ({
        bar: { networkWidth: 320, audioWidth: 320, batteryWidth: 250 }
    })
}
