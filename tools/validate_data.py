#!/usr/bin/env python3
"""Data-level regression checks; does NOT replace an Xcode/iOS build."""
from pathlib import Path
import json
import re
import sys
import plistlib
import hashlib

root = Path(__file__).resolve().parents[1]
resource = root / "LyceumMobile/Resources"
filenames = (
    "schedule_numerator.json", "schedule_denominator.json",
    "shelter_numerator.json", "shelter_denominator.json",
)
canonical_classes = {"10-А", "10-Б", "10-В", "10-Г",
                     "11-А", "11-Б", "11-В", "11-Г"}
for file in filenames:
    obj = json.loads((resource / file).read_text(encoding="utf8"))
    assert obj["weekType"] == ("NUMERATOR" if file.endswith("numerator.json")
                                and "denominator" not in file else "DENOMINATOR"), file
    assert len(obj["bellSchedule"]) == 8, file
    for day, lessons in obj["days"].items():
        assert day in {"MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY","SUNDAY"}
        for lesson, classes in lessons.items():
            assert lesson.isdigit()
            for klass, items in classes.items():
                assert klass in canonical_classes, (file, klass)
                assert all(all(k in e for k in ("subject", "room", "teacher")) for e in items)
    print(f"OK {file}: 8 bells, valid day/class structure")
calendar = json.loads((resource/"calendar.json").read_text(encoding="utf8"))
assert "daysOff" in calendar and "ranges" in calendar
plistlib.loads((root/"LyceumMobile/Info.plist").read_bytes())
manifest_code = (root/"LyceumMobile/Services/ScheduleStore.swift").read_text(encoding="utf8")
alert_code = (root/"LyceumMobile/Services/AlertsService.swift").read_text(encoding="utf8")
metronome_code = (root/"LyceumMobile/Services/SilenceMetronome.swift").read_text(encoding="utf8")
assert "SHA256.hash" in manifest_code
assert "81.json" in alert_code and 'case active = "A"' in alert_code
assert "Timer(timeInterval: 1.0" in metronome_code
assert "AVAudioSession" in metronome_code
appfiles = list((root/"LyceumMobile").rglob("*.swift"))
assert len(appfiles) >= 18, len(appfiles)
print(f"OK {len(appfiles)} Swift source files, four offline timetables, iOS Info.plist.")

# iOS 15 compatibility contract.
pbx = (root/"LyceumMobile.xcodeproj/project.pbxproj").read_text(encoding="utf8")
assert pbx.count("IPHONEOS_DEPLOYMENT_TARGET = 15.0;") == 4
assert "IPHONEOS_DEPLOYMENT_TARGET = 16.0;" not in pbx
assert "CURRENT_PROJECT_VERSION = 2;" in pbx

ios16_only = (
    "NavigationStack", "NavigationSplitView", "LabeledContent",
    "scrollContentBackground", "ShareLink", "PhotosPicker",
    "presentationDetents", "toolbarBackground", "ViewThatFits",
    "AnyLayout", "GridRow",
)
for source in appfiles:
    code = source.read_text(encoding="utf8")
    for symbol in ios16_only:
        assert symbol not in code, (source.name, symbol)
    assert not re.search(r"TextField\([\s\S]{0,300}?axis\s*:", code), source.name

codemagic = (root/"codemagic.yaml").read_text(encoding="utf8")
assert "IPHONEOS_DEPLOYMENT_TARGET=15.0" in codemagic
assert "LyceumMobile-unsigned.ipa" in codemagic
print("OK iOS 15 deployment target, compatibility scan and unsigned IPA workflow.")

core_code = (root/"LyceumMobile/Core/ScheduleEngine.swift").read_text(encoding="utf8")
assert "Date.FormatStyle" not in core_code
assert ".formatted(style)" not in core_code
assert 'formatter.dateFormat = "HH:mm"' in core_code
print("OK shared Core avoids macOS 12-only Date.FormatStyle APIs.")

ui_sources = "\n".join(
    source.read_text(encoding="utf8")
    for source in (root/"LyceumMobile/Views").rglob("*.swift")
)
assert ".toolbar(.hidden, for: .navigationBar)" not in ui_sources
assert ".contentTransition(" not in ui_sources
assert ".numericText()" not in ui_sources
assert ".navigationBarHidden(true)" in ui_sources
print("OK iOS 15 navigation-bar and numeric-text compatibility guards.")

all_swift_ui = "\n".join(
    source.read_text(encoding="utf8")
    for source in (root/"LyceumMobile").rglob("*.swift")
)
assert ".tracking(" not in all_swift_ui
assert ".kerning(" not in all_swift_ui
print("OK iOS 15 text-spacing compatibility: no .tracking()/.kerning().")
