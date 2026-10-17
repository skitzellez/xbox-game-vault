// Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
// PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
// Helper for GameVault-Setup.sh (Mac): reads the console's and GitHub's JSON answers and edits XBSX2's settings
// text. A Mac runs it with its own JavaScript (osascript -l JavaScript), so nothing has to be installed; with
// Node.js it runs the same way (used for testing on other systems).
//   helper.js <file> <command> [arguments...]   prints the answer, one value per line, fields split by tabs

function main(text, cmd, a, write) {
    if (cmd === "padfix") {                   // a[0]: where to write the new settings; prints "changed" or nothing
        var t = addPadButtons(text);
        if (t === null) return "";
        write(a[0], t);
        return "changed";
    }
    if (cmd === "hasPad1") return /^\[Pad1\]/m.test(text) ? "yes" : "";
    var d;
    try { d = JSON.parse(text); } catch (e) { return ""; }
    if (d === null || d === undefined) return "";
    switch (cmd) {
    case "get":                               // a[0]: a field name, e.g. Platform
        return d[a[0]] === undefined || d[a[0]] === null ? "" : String(d[a[0]]);
    case "setting":                           // a[0]: a Device Portal setting's name -> its value
        var s = (d.Settings || []).filter(function (x) { return x.Name === a[0]; })[0];
        return s ? String(s.Value) : "";
    case "package":                           // a[0]: package name start -> full name, family, app id, version
        var p = (d.InstalledPackages || []).filter(function (x) {
            return x.PackageFullName.toLowerCase().indexOf(a[0].toLowerCase()) === 0;
        })[0];
        if (!p) return "";
        var v = p.Version || {};
        return [p.PackageFullName, p.PackageFamilyName || "", p.PackageRelativeId || "",
                [v.Major, v.Minor, v.Build, v.Revision].join(".")].join("\t");
    case "state":                             // the install state after the console finished: ok, or the reason
        if (d.Success) return "ok";
        return ((d.Reason || "") + " " + (d.CodeText || "")).trim() || "failed";
    case "items":                             // folder listing: one "dir|file<TAB>name" per line
        return (d.Items || []).map(function (i) { return ((i.Type & 16) ? "dir" : "file") + "\t" + i.Name; }).join("\n");
    case "release":                           // a[0]: file name pattern -> url, name, version, size in MB
        if (!(d instanceof Array)) return "ERROR";
        var re = new RegExp(a[0], "i");
        var rels = d.slice().sort(function (x, y) { return x.published_at < y.published_at ? 1 : x.published_at > y.published_at ? -1 : 0; });
        for (var i = 0; i < rels.length; i++) {
            var as = (rels[i].assets || []).filter(function (x) { return re.test(x.name); });
            if (!as.length) continue;
            var m = as[0].name.match(/(\d+(\.\d+)+)/);
            var ver = m ? m[1] : String(rels[i].tag_name || "").replace(/^[^\d]*/, "");
            return [as[0].browser_download_url, as[0].name, ver, Math.round(as[0].size / 1048576)].join("\t");
        }
        return "";
    case "stabletag":                         // newest release that is not a test release
        if (!(d instanceof Array)) return "ERROR";
        var st = d.filter(function (x) { return !x.prerelease; })
                  .sort(function (x, y) { return x.published_at < y.published_at ? 1 : -1; })[0];
        return st ? String(st.tag_name).replace(/^v/, "") : "";
    }
    return "";
}

// XBSX2 writes its first settings with no buttons assigned. Adds the usual layout to controller ports 1 and 2
// where a port has none (A = Cross, B = Circle, X = Square, Y = Triangle, Menu = Start, View = Select).
// null: nothing to add. Same rules as the Windows setup.
function padButtons(n) {
    var names = ["Up=DPadUp", "Right=DPadRight", "Down=DPadDown", "Left=DPadLeft", "Triangle=FaceNorth", "Circle=FaceEast",
                 "Cross=FaceSouth", "Square=FaceWest", "Select=Back", "Start=Start", "L1=LeftShoulder", "L2=+LeftTrigger",
                 "R1=RightShoulder", "R2=+RightTrigger", "L3=LeftStick", "R3=RightStick", "LUp=-LeftY", "LRight=+LeftX",
                 "LDown=+LeftY", "LLeft=-LeftX", "RUp=-RightY", "RRight=+RightX", "RDown=+RightY", "RLeft=-RightX",
                 "LargeMotor=LargeMotor", "SmallMotor=SmallMotor"];
    return names.map(function (x) { var kv = x.split("="); return kv[0] + " = SDL-" + n + "/" + kv[1]; });
}
function padSection(text, port) {             // the [PadN] section: its start, length and body
    var re = new RegExp("^\\[Pad" + port + "\\]\\r?\\n", "m");
    var m = re.exec(text);
    if (!m) return null;
    var start = m.index, bodyStart = start + m[0].length;
    var next = text.slice(bodyStart).search(/^\[/m);
    var end = next < 0 ? text.length : bodyStart + next;
    return { start: start, length: end - start, body: text.slice(bodyStart, end) };
}
function addPadButtons(text) {
    var nl = text.indexOf("\r\n") >= 0 ? "\r\n" : "\n";
    var changed = false;
    for (var n = 0; n < 2; n++) {
        var sec = padSection(text, n + 1);
        if (!sec) continue;
        var lines = sec.body.split(/\r?\n/).filter(function (l) { return l.trim(); });
        if (lines.some(function (l) { return /^Cross\s*=/.test(l); })) continue;        // has buttons already
        var typeLine = lines.filter(function (l) { return /^Type\s*=/.test(l); })[0] || "";
        var type = typeLine.replace(/^Type\s*=\s*/, "");
        if (n === 1 && type === "None") {
            // a second controller: the same kind and settings as the first
            var first = padSection(text, 1);
            lines = (first ? first.body : "").split(/\r?\n/).filter(function (l) { return l.trim() && l.indexOf("SDL-") < 0; });
            type = "DualShock2";
        }
        if (type !== "DualShock2") continue;
        var section = ["[Pad" + (n + 1) + "]"].concat(lines, padButtons(n), ["", "", ""]).join(nl);
        text = text.slice(0, sec.start) + section + text.slice(sec.start + sec.length);
        changed = true;
    }
    return changed ? text : null;
}

// --- how it is started -------------------------------------------------------------------------------------
// a Mac: osascript -l JavaScript helper.js <file> <command> ... calls run() and prints what it returns
function run(argv) {
    ObjC.import("Foundation");
    var s = $.NSString.stringWithContentsOfFileEncodingError($(argv[0]), $.NSUTF8StringEncoding, null);
    var text = (s && !s.isNil()) ? s.js : "";
    return main(text, argv[1], argv.slice(2), function (path, t) {
        $(t).writeToFileAtomicallyEncodingError($(path), true, $.NSUTF8StringEncoding, null);
    });
}
if (typeof ObjC === "undefined" && typeof require !== "undefined") {  // Node.js: node helper.js <file> <command> ...
    var fs = require("fs");
    var args = process.argv.slice(2);
    var text = "";
    try { text = fs.readFileSync(args[0], "utf8"); } catch (e) { }
    process.stdout.write(main(text, args[1], args.slice(2), function (path, t) { fs.writeFileSync(path, t); }) + "\n");
}
