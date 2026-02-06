#!/bin/bash
echo "📋 Clipboard Diagnostic Tool"
echo "============================"
echo "User: $(whoami) (UID: $(id -u))"
echo "DISPLAY: $DISPLAY"
echo "WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
echo "XAUTHORITY: $XAUTHORITY"

echo -e "\n🔍 Checking Tools:"
for tool in xclip xsel wl-copy; do
    if command -v $tool >/dev/null; then
        echo "  ✅ $tool found: $(which $tool)"
    else
        echo "  ❌ $tool NOT found"
    fi
done

echo -e "\n🧪 Testing X11 (xclip):"
if [[ -n "$DISPLAY" ]]; then
    echo "X11 Test" | xclip -sel clip -verbose 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✅ xclip command succeeded."
        echo "  👉 Please paste on host to confirm content is 'X11 Test'"
    else
        echo "  ❌ xclip command FAILED."
    fi
else
    echo "  ⚠️ Skipping (DISPLAY not set)"
fi

echo -e "\n🧪 Testing Wayland (wl-copy):"
if [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo "Wayland Test" | wl-copy --verbose 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✅ wl-copy command succeeded."
        echo "  👉 Please paste on host to confirm content is 'Wayland Test'"
    else
        echo "  ❌ wl-copy command FAILED."
        echo "  ℹ️  Note: Wayland often fails due to UID mismatch (Host: $HOST_UID vs Container: $(id -u))"
    fi
else
    echo "  ⚠️ Skipping (WAYLAND_DISPLAY not set)"
fi
