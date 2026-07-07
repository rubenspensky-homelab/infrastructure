# Debian Autoinstall ISO

This directory builds a custom Debian installer ISO by injecting `preseed.cfg` into the Debian installer initrd and configuring the boot menu to start the automated installer by default.

The script does not download Debian and does not write USB drives.

## Files

- `preseed.cfg`: Debian preseed answer file.
- `build-iso.sh`: Builds a custom ISO from a local Debian netinst ISO.
- `dist/debian-autoinstall-ops.iso`: Generated ISO output.

## Password Hash

The `ops` password must be stored as a SHA-512 crypt hash in `preseed.cfg`.

Generate it with:

```sh
openssl passwd -6
```

Then replace this placeholder in `preseed.cfg`:

```text
$6$REPLACE_WITH_SHA512_CRYPT_HASH
```

with the generated hash.

## Build

Put a Debian amd64 netinst ISO in this directory, for example:

```text
debian-13.5.0-amd64-netinst.iso
```

Then run:

```sh
./build-iso.sh
```

Or pass the ISO path explicitly:

```sh
./build-iso.sh /path/to/debian-13.5.0-amd64-netinst.iso
```

The output is:

```text
dist/debian-autoinstall-ops.iso
```

The generated ISO boots directly into the automated text installer for both BIOS and UEFI boot paths.

## Installed System

The generated installer creates:

- User `ops`.
- SSH access using the public key embedded in `preseed.cfg`.
- SSH password authentication disabled.
- `sudo`, `python3`, `openssh-server`, `ca-certificates`, and `curl`.
- `ops` only belongs to the `sudo` default group.
- Passwordless sudo for `ops`, suitable for Ansible.

Disk selection is destructive:

- Prefer disk serial `PNY4519191104030431D`.
- If that disk is not present, use the first non-removable disk found.

## USB Write

This script does not write USB drives. If you want to write the generated ISO manually, verify the target device first and then run something like:

```sh
sudo dd if=dist/debian-autoinstall-ops.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the actual USB device.
