// AnchorAnimation on the same Material 3 Expressive scale as Anim, for
// transitions that move an item between anchor lines.
// Ported from caelestia-shell components/AnchorAnim.qml; the easing curve is a
// bezier control-point list rather than a QEasingCurve handed over from C++.
import QtQuick
import common

AnchorAnimation {
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
        SlowSpatial
    }

    property int type: AnchorAnim.DefaultSpatial

    readonly property var _d: Tokens.anim.durations
    readonly property var _c: Tokens.anim.curves

    readonly property string _token: {
        if (type === AnchorAnim.FastSpatial)
            return "expressiveFastSpatial";
        if (type === AnchorAnim.DefaultSpatial)
            return "expressiveDefaultSpatial";
        if (type === AnchorAnim.SlowSpatial)
            return "expressiveSlowSpatial";
        return "";
    }

    duration: {
        if (type < AnchorAnim.StandardSmall || type > AnchorAnim.SlowSpatial)
            return _d.expressiveDefaultSpatial;
        if (_token)
            return _d[_token];
        // 0-7 are the four standard sizes, twice over.
        return _d[["small", "normal", "large", "extraLarge"][type % 4]];
    }

    easing.type: Easing.Bezier
    easing.bezierCurve: {
        if (_token)
            return _c[_token];
        if (type >= AnchorAnim.StandardSmall && type <= AnchorAnim.StandardExtraLarge)
            return _c.standard;
        if (type >= AnchorAnim.EmphasizedSmall && type <= AnchorAnim.EmphasizedExtraLarge)
            return _c.emphasized;
        return _c.expressiveDefaultSpatial;
    }
}
