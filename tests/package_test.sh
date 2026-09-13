#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
GODOT="${GODOT_BIN:-godot}"
archive="$ROOT_DIR/dist/@aviorstudio_gd-network.zip"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

test -f "$archive"
(cd "$ROOT_DIR/dist" && sha256sum --check --strict '@aviorstudio_gd-network.zip.sha256')
python3 "$SCRIPT_DIR/verify_zip.py" "$archive" "$ROOT_DIR/addon/package-manifest.txt"

addon_dir="$fixture/addons/@aviorstudio_gd-network"
mkdir -p "$addon_dir"
unzip -q "$archive" -d "$addon_dir"
cat > "$fixture/project.godot" <<'EOF'
[application]
config/name="gd-network packaged acceptance"

[editor_plugins]
enabled=PackedStringArray("res://addons/@aviorstudio_gd-network/plugin.cfg")

[consumer]
owned_value="preserve-me"
EOF

timeout --signal=TERM --kill-after=5 30 "$GODOT" --headless --editor --path "$fixture" --quit-after 2
timeout --signal=TERM --kill-after=5 30 "$GODOT" --headless --editor --path "$fixture" --quit-after 2
cat > "$fixture/smoke.gd" <<'EOF'
extends SceneTree

func _initialize() -> void:
	var client_script := load("res://addons/@aviorstudio_gd-network/src/http_client_module.gd")
	var pool_script := load("res://addons/@aviorstudio_gd-network/src/http_pool_module.gd")
	if client_script == null or pool_script == null:
		push_error("packaged addon smoke load failed")
		quit(1)
		return
	var client = client_script.new()
	if client == null:
		push_error("packaged addon smoke construction failed")
		quit(1)
		return
	print("PACKAGED_SMOKE_REACHED")
	quit(0)
EOF
GODOT_PROJECT_ROOT="$fixture" "$SCRIPT_DIR/run_godot_test.sh" "$fixture/smoke.gd" PACKAGED_SMOKE_REACHED 30

cat > "$fixture/project.godot" <<'EOF'
[application]
config/name="gd-network packaged acceptance"

[editor_plugins]
enabled=PackedStringArray()

[consumer]
owned_value="preserve-me"
EOF
timeout --signal=TERM --kill-after=5 30 "$GODOT" --headless --editor --path "$fixture" --quit-after 2
timeout --signal=TERM --kill-after=5 30 "$GODOT" --headless --editor --path "$fixture" --quit-after 2
grep -Fq 'owned_value="preserve-me"' "$fixture/project.godot"
if grep -Eq '^\[autoload\]' "$fixture/project.godot"; then
    echo "Packaged addon unexpectedly left autoload configuration" >&2
    exit 1
fi

(cd "$addon_dir" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) | sha256sum | awk '{print $1}' > "$ROOT_DIR/dist/installed-tree.sha256"
echo "PASS package_test enabled_restart=1 smoke=1 disabled_restart=1 consumer_config=preserved"
