// Self-check for tools.js: node nova/.config/quickshell/island/tools.test.js
const fs = require("fs");
const assert = require("assert");
const T = new Function(fs.readFileSync(__dirname + "/tools.js", "utf8") +
    "; return { calc, parseDuration, parseAlarm, nextAt, fmt, fmtIn, clock12 };")();

assert.strictEqual(T.calc("2 * (3 + 4)^2"), "98");
assert.strictEqual(T.calc("0.1 + 0.2"), "0.3");
assert.strictEqual(T.calc("sqrt(16) + pi"), String(parseFloat((4 + Math.PI).toPrecision(12))));
assert.strictEqual(T.calc("1,000 x 3"), "3000");
assert.strictEqual(T.calc("10 ÷ 4"), "2.5");
assert.strictEqual(T.calc(""), "");
assert.strictEqual(T.calc("2 +"), null);
assert.strictEqual(T.calc("1/0"), null);
assert.strictEqual(T.calc("constructor"), null);
assert.strictEqual(T.calc("alert(1)"), null);
assert.strictEqual(T.calc("[]"), null);

assert.strictEqual(T.parseDuration("5"), 300);
assert.strictEqual(T.parseDuration("90s"), 90);
assert.strictEqual(T.parseDuration("1h30m"), 5400);
assert.strictEqual(T.parseDuration("1h 30"), 5400);
assert.strictEqual(T.parseDuration("5:00"), 300);
assert.strictEqual(T.parseDuration("1:05:00"), 3900);
assert.strictEqual(T.parseDuration("abc"), 0);
assert.strictEqual(T.parseDuration(""), 0);

assert.deepStrictEqual(T.parseAlarm("7:30"), { h: 7, m: 30, label: "" });
assert.deepStrictEqual(T.parseAlarm("730pm Gym"), { h: 19, m: 30, label: "Gym" });
assert.deepStrictEqual(T.parseAlarm("12am"), { h: 0, m: 0, label: "" });
assert.deepStrictEqual(T.parseAlarm("12:15 pm"), { h: 12, m: 15, label: "" });
assert.deepStrictEqual(T.parseAlarm("19:30 Stand up"), { h: 19, m: 30, label: "Stand up" });
assert.strictEqual(T.parseAlarm("25:00"), null);
assert.strictEqual(T.parseAlarm("13pm"), null);
assert.strictEqual(T.parseAlarm("wake"), null);

const now = new Date(2026, 10, 4, 8, 0);
assert.strictEqual(T.nextAt(9, 0, now), new Date(2026, 10, 4, 9, 0).getTime());
assert.strictEqual(T.nextAt(8, 0, now), new Date(2026, 10, 5, 8, 0).getTime());

assert.strictEqual(T.fmt(65000), "1:05");
assert.strictEqual(T.fmt(3723000), "1:02:03");
assert.strictEqual(T.fmt(65430, true), "1:05.43");
assert.strictEqual(T.fmtIn(3 * 3600000 + 12 * 60000), "3h 12m");
assert.strictEqual(T.clock12(0, 5), "12:05 AM");
console.log("tools.js ok");
