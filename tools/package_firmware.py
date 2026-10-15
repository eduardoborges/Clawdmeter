#!/usr/bin/env python3
"""Packs built firmware into one zip per board for the Mac app's flasher.

Each zip holds the images and a manifest.json with the chip and the offset of
every segment. The NVS partition is not in it, so flashing keeps the BLE bond
and the saved settings.

    tools/package_firmware.py [env ...]    # default: every board env

Run `pio run -d firmware -e <env>` first. Zips land in dist/.
"""
import json
import pathlib
import struct
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIRMWARE = ROOT / "firmware"
DIST = ROOT / "dist"
BOARDS = ["waveshare_amoled_216", "waveshare_amoled_18", "waveshare_amoled_216_c6",
          "waveshare_amoled_18_c6", "waveshare_amoled_206", "waveshare_lcd_154", "waveshare_lcd_4"]


def app_offset(partitions: pathlib.Path) -> int:
    """The first app partition in a binary partition table."""
    data = partitions.read_bytes()
    for i in range(0, len(data), 32):
        magic, kind, _subtype, offset = struct.unpack_from("<HBBI", data, i)
        if magic != 0x50AA:
            break
        if kind == 0:
            return offset
    raise SystemExit(f"{partitions}: no app partition")


def package(env: str) -> pathlib.Path:
    out = subprocess.run(["pio", "project", "metadata", "-d", str(FIRMWARE), "-e", env, "--json-output"],
                         check=True, capture_output=True, text=True).stdout
    meta = json.loads(out)[env]
    build = FIRMWARE / ".pio" / "build" / env
    images = [(int(i["offset"], 16), pathlib.Path(i["path"])) for i in meta["extra"]["flash_images"]]
    images.append((app_offset(build / "partitions.bin"), build / "firmware.bin"))
    chip = "esp32c6" if env.endswith("_c6") else "esp32s3"   # the two SoCs the boards use
    manifest = {"env": env, "chip": chip,
                "segments": [{"offset": hex(offset), "file": path.name} for offset, path in sorted(images)]}
    DIST.mkdir(exist_ok=True)
    zip_path = DIST / f"tally-firmware-{env}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
        for _, path in images:
            z.write(path, path.name)
    return zip_path


if __name__ == "__main__":
    for env in sys.argv[1:] or BOARDS:
        print(package(env))
