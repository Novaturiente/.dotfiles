// NumberAnimation preset onto the Material 3 Expressive motion scale.
// Ported from caelestia-shell components/Anim.qml; the easing curve is applied
// as a bezier control-point list instead of a QEasingCurve handed over from C++.
//
// Usage: `Behavior on x { Anim { type: Anim.FastSpatial } }`
// Override a single curve with `curve: Tokens.anim.curves.emphasizedDecel`.
import QtQuick
import common

NumberAnimation {
    id: root

    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial
    // Optional explicit curve, as a bezier control-point list from Tokens.anim.curves.
    property var curve: undefined

    readonly property var _d: Tokens.anim.durations
    readonly property var _c: Tokens.anim.curves

    // Names of the expressive tokens, indexed by the enum values 8..13.
    readonly property var _expressive: [
        "expressiveFastSpatial", "expressiveDefaultSpatial", "expressiveSlowSpatial",
        "expressiveFastEffects", "expressiveDefaultEffects", "expressiveSlowEffects"
    ]

    readonly property string _token: type >= Anim.FastSpatial && type <= Anim.SlowEffects ? _expressive[type - Anim.FastSpatial] : ""

    duration: {
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return _d.normal;
        if (_token)
            return _d[_token];
        // 0-7 are the four standard sizes, twice over (standard then emphasized).
        return _d[["small", "normal", "large", "extraLarge"][type % 4]];
    }

    easing.type: Easing.Bezier
    easing.bezierCurve: {
        if (curve !== undefined)
            return curve;
        if (_token)
            return _c[_token];
        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return _c.emphasized;
        return _c.standard;
    }
}
