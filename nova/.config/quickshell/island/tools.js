// Pure helpers for ToolsPage.qml, kept out of QML so node can check them:
//   node nova/.config/quickshell/island/tools.test.js

// Names a calculator expression may use; anything else is rejected, which
// keeps the Function() below from ever seeing arbitrary code.
const NAMES = {
    sqrt: "Math.sqrt", cbrt: "Math.cbrt", abs: "Math.abs",
    sin: "Math.sin", cos: "Math.cos", tan: "Math.tan",
    asin: "Math.asin", acos: "Math.acos", atan: "Math.atan",
    ln: "Math.log", log: "Math.log10", exp: "Math.exp",
    floor: "Math.floor", ceil: "Math.ceil", round: "Math.round",
    pi: "Math.PI", e: "Math.E", x: "*"
};

// "" for an empty expression, null when it does not evaluate, else the answer
// as text. ^ is power, x/× multiply, ÷ divide, % modulo, commas are ignored.
function calc(expr) {
    let s = expr.toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "").replace(/\^/g, "**");
    if (s.trim() === "")
        return "";
    if (/[^0-9a-z+\-*/%().\s]/.test(s))
        return null;
    let bad = false;
    s = s.replace(/[a-z]+/g, w => NAMES[w] || (bad = true, w));
    if (bad)
        return null;
    try {
        const v = Function("return (" + s + ")")();
        if (typeof v !== "number" || !isFinite(v))
            return null;
        return String(parseFloat(v.toPrecision(12)));
    } catch (err) {
        return null;
    }
}

// Duration text to seconds, 0 when it does not parse.
// "5" = 5 min, "90s", "1h30m", "1h 30", "5:00" (m:ss), "1:05:00" (h:mm:ss).
function parseDuration(text) {
    const s = text.trim().toLowerCase();
    if (/^\d+(:\d{1,2}){1,2}$/.test(s))
        return s.split(":").reduce((acc, p) => acc * 60 + parseInt(p), 0);
    if (!/^(\d+(\.\d+)?\s*[hms]?\s*)+$/.test(s))
        return 0;
    const unit = { h: 3600, m: 60, s: 1 };
    const re = /(\d+(?:\.\d+)?)\s*([hms]?)/g;
    let total = 0, m;
    while ((m = re.exec(s)))
        total += parseFloat(m[1]) * unit[m[2] || "m"];
    return Math.round(total);
}

// "7:30", "730", "7:30pm", "19:30 Standup", "7 am Wake up" -> {h, m, label}, or null.
function parseAlarm(text) {
    const r = /^\s*(\d{1,2})(?:[:.]?(\d{2}))?\s*(am|pm|a|p)?(?:\s+(.*))?$/i.exec(text);
    if (!r)
        return null;
    let h = parseInt(r[1]);
    const m = r[2] ? parseInt(r[2]) : 0;
    const ap = (r[3] || "").toLowerCase();
    if (m > 59 || (ap && (h < 1 || h > 12)) || h > 23)
        return null;
    if (ap)
        h = h % 12 + (ap[0] === "p" ? 12 : 0);
    return { h: h, m: m, label: (r[4] || "").trim() };
}

// Next time h:m happens after `now` (a Date), as epoch ms.
function nextAt(h, m, now) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m, 0, 0);
    if (d.getTime() <= now.getTime())
        d.setDate(d.getDate() + 1);
    return d.getTime();
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// 7:05 AM
function clock12(h, m) {
    return (h % 12 || 12) + ":" + pad(m) + (h < 12 ? " AM" : " PM");
}

// ms -> "1:02:03" or "2:03"; `cs` adds hundredths ("2:03.45").
function fmt(ms, cs) {
    const t = Math.max(0, Math.floor(ms / 1000));
    const h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
    const base = (h ? h + ":" + pad(m) : m) + ":" + pad(s);
    return cs ? base + "." + pad(Math.floor(ms / 10) % 100) : base;
}

// ms -> "3h 12m" / "12m" / "<1m", for "rings in".
function fmtIn(ms) {
    const mins = Math.ceil(ms / 60000);
    if (mins < 1)
        return "<1m";
    return (mins >= 60 ? Math.floor(mins / 60) + "h " : "") + (mins % 60) + "m";
}
