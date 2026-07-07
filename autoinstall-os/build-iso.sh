#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESEED_FILE="${PRESEED_FILE:-${SCRIPT_DIR}/preseed.cfg}"
ISO_PATH="${1:-${DEBIAN_ISO_PATH:-}}"
WORK_DIR="${SCRIPT_DIR}/work"
EXTRACT_DIR="${WORK_DIR}/extract"
INITRD_DIR="${WORK_DIR}/initrd"
DIST_DIR="${SCRIPT_DIR}/dist"
OUTPUT_ISO="${OUTPUT_ISO:-${DIST_DIR}/debian-autoinstall-ops.iso}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    return 1
  fi
}

check_dependencies() {
  local missing=0
  for cmd in basename cat chmod cp cpio dirname grep gzip mkdir readlink rm tr xorriso; do
    if ! need_cmd "$cmd"; then
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    printf '\nInstall dependencies with:\n' >&2
    printf '  sudo apt install xorriso gzip cpio coreutils\n' >&2
    exit 1
  fi
}

select_source_iso() {
  local candidates=()
  local candidate

  if [[ -n "$ISO_PATH" ]]; then
    return 0
  fi

  shopt -s nullglob
  candidates=(
    "$SCRIPT_DIR"/debian-*-amd64-netinst.iso
    "$SCRIPT_DIR"/*.iso
  )
  shopt -u nullglob

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      ISO_PATH="$candidate"
      return 0
    fi
  done
}

validate_inputs() {
  select_source_iso

  if [[ -z "$ISO_PATH" ]]; then
    printf 'No Debian ISO provided or found.\n' >&2
    printf 'Usage:\n  %s /path/to/debian-amd64-netinst.iso\n' "$0" >&2
    printf 'Or put the ISO next to this script.\n' >&2
    exit 1
  fi

  if [[ ! -s "$ISO_PATH" ]]; then
    printf 'Debian ISO not found or empty: %s\n' "$ISO_PATH" >&2
    exit 1
  fi

  if [[ ! -s "$PRESEED_FILE" ]]; then
    printf 'preseed.cfg not found or empty: %s\n' "$PRESEED_FILE" >&2
    exit 1
  fi

  if grep -q 'REPLACE_WITH_SHA512_CRYPT_HASH' "$PRESEED_FILE"; then
    printf 'Replace the placeholder password hash in %s before building.\n' "$PRESEED_FILE" >&2
    exit 1
  fi
}

extract_iso() {
  rm -rf "$WORK_DIR"
  mkdir -p "$EXTRACT_DIR"

  printf 'Using source ISO:\n  %s\n' "$ISO_PATH"
  printf 'Extracting ISO contents...\n'
  xorriso -osirrox on -indev "$ISO_PATH" -extract / "$EXTRACT_DIR" >/dev/null
  chmod -R u+w "$EXTRACT_DIR"
}

inject_preseed_into_initrd() {
  local initrd_path
  local tmp_dir
  local found=0

  for initrd_path in "$EXTRACT_DIR"/install.amd/initrd.gz "$EXTRACT_DIR"/install.amd/gtk/initrd.gz; do
    [[ -f "$initrd_path" ]] || continue
    found=1
    tmp_dir="${INITRD_DIR}/$(basename "$(dirname "$initrd_path")")"
    mkdir -p "$tmp_dir/add"
    cp "$PRESEED_FILE" "$tmp_dir/add/preseed.cfg"

    printf 'Injecting preseed.cfg into installer initrd:\n  %s\n' "$initrd_path"
    gzip -d -c "$initrd_path" > "$tmp_dir/initrd"
    (
      cd "$tmp_dir/add"
      printf '%s\n' preseed.cfg | cpio -H newc -o -A -F "$tmp_dir/initrd" >/dev/null
    )
    gzip -9 -c "$tmp_dir/initrd" > "$initrd_path"
  done

  if [[ "$found" -eq 0 ]]; then
    printf 'Could not find Debian installer initrd under install.amd/.\n' >&2
    exit 1
  fi
}

configure_auto_boot() {
  local isolinux_cfg="${EXTRACT_DIR}/isolinux/isolinux.cfg"
  local txt_cfg="${EXTRACT_DIR}/isolinux/txt.cfg"
  local grub_cfg="${EXTRACT_DIR}/boot/grub/grub.cfg"

  if [[ -f "$isolinux_cfg" && -f "$txt_cfg" ]]; then
    printf 'Configuring BIOS boot menu for automatic install...\n'
    cat > "$isolinux_cfg" <<'EOF'
# D-I config version 2.0
path 
prompt 0
timeout 1
include txt.cfg
default install
EOF

    cat > "$txt_cfg" <<'EOF'
label install
	menu label ^Automated install
	kernel /install.amd/vmlinuz
	append auto=true priority=critical vga=788 initrd=/install.amd/initrd.gz --- quiet
EOF
  fi

  if [[ -f "$grub_cfg" ]]; then
    printf 'Configuring UEFI boot menu for automatic install...\n'
    cat > "$grub_cfg" <<'EOF'
set default=0
set timeout=0

menuentry 'Automated install' {
    set background_color=black
    linux    /install.amd/vmlinuz auto=true priority=critical vga=788 --- quiet
    initrd   /install.amd/initrd.gz
}
EOF
  fi
}

rebuild_iso() {
  local boot_opts_file="${WORK_DIR}/mkisofs-boot-opts.txt"
  local boot_opts

  mkdir -p "$DIST_DIR"
  rm -f "$OUTPUT_ISO"

  printf 'Reading boot metadata from source ISO...\n'
  xorriso -indev "$ISO_PATH" -report_el_torito as_mkisofs > "$boot_opts_file"
  boot_opts="$(tr '\n' ' ' < "$boot_opts_file")"

  printf 'Building custom ISO:\n  %s\n' "$OUTPUT_ISO"
  eval "set -- $boot_opts"
  xorriso -as mkisofs "$@" -o "$OUTPUT_ISO" "$EXTRACT_DIR"
}

main() {
  check_dependencies
  validate_inputs
  extract_iso
  inject_preseed_into_initrd
  configure_auto_boot
  rebuild_iso

  printf '\nCustom Debian autoinstall ISO created:\n  %s\n' "$OUTPUT_ISO"
}

main "$@"
