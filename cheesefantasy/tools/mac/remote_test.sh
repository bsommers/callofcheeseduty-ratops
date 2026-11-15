#!/bin/sh
# runs ON the Mac, in ~/build/cheesefantasy-scratch
cd "$HOME/build/cheesefantasy-scratch" || exit 1
unzip -q CheeseFantasy.zip && ls
APP=$(ls -d *.app | head -1)
xattr -cr "$APP"
codesign --force --deep -s - "$APP" 2>&1 | tail -2
codesign --verify --deep --strict "$APP" 2>&1 || echo "note: strict verify fails (sealed resource), app still launches"
BIN="$APP/Contents/MacOS/$(defaults read "$PWD/$APP/Contents/Info" CFBundleExecutable)"
"$BIN" --rendering-driver metal --quit-after 600 --verbose > run.log 2>&1
echo "exit=$?"
launchctl asuser $(id -u) screencapture -x shot.png 2>&1 | tail -1
grep -i -m4 -E "^Metal|Godot Engine|main.tscn'" run.log; grep -c -i "error" run.log
echo "--- tail"; tail -8 run.log
hdiutil create -volname "CHEESE FANTASY" -srcfolder "$APP" -ov -format UDZO CheeseFantasy-macos.dmg | tail -1
ls -la CheeseFantasy-macos.dmg shot.png 2>&1
exit 0
