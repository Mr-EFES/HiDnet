#!/usr/bin/env python3
"""Package an iPhone archive, keeping its Packet Tunnel extension."""

import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent


def bundle_info(bundle):
    with (bundle / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    executable = info.get("CFBundleExecutable", "")
    if not executable or Path(executable).name != executable or not (bundle / executable).is_file():
        raise ValueError("Missing bundle executable: " + str(bundle))
    if not info.get("CFBundleIdentifier"):
        raise ValueError("Missing bundle identifier: " + str(bundle))
    if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
        raise ValueError("An iPhone device build is required, not a simulator build.")
    return info


def sign_for_resigning(app, tunnel, temporary):
    if sys.platform != "darwin":
        raise ValueError("Ad-hoc signing requires codesign on macOS.")
    for binary in sorted(list(app.rglob("*.framework")) + list(app.rglob("*.dylib")),
                         key=lambda path: len(path.parts), reverse=True):
        subprocess.run(["codesign", "--force", "--sign", "-", "--timestamp=none", str(binary)], check=True)
    for index, bundle in enumerate((tunnel, app)):
        info = bundle_info(bundle)
        group = info.get("HiDnetKeychainGroup", "")
        if not group or "$(" in group:
            raise ValueError("Keychain group was not expanded by Xcode.")
        entitlements = {
            "com.apple.developer.networking.networkextension": ["packet-tunnel-provider"],
            "keychain-access-groups": [group],
        }
        entitlement_file = temporary / ("entitlements-" + str(index) + ".plist")
        with entitlement_file.open("wb") as stream:
            plistlib.dump(entitlements, stream)
        subprocess.run([
            "codesign", "--force", "--sign", "-", "--timestamp=none",
            "--generate-entitlement-der", "--entitlements", str(entitlement_file), str(bundle)
        ], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)


def package(archive, output, ad_hoc_sign=False):
    source = archive / "Products/Applications/HiDnet.app"
    app_info = bundle_info(source)
    tunnel_source = source / "PlugIns/HiDnetTunnel.appex"
    tunnel_info = bundle_info(tunnel_source)
    if tunnel_info.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.networkextension.packet-tunnel":
        raise ValueError("The Packet Tunnel extension is missing or invalid.")
    if not tunnel_info["CFBundleIdentifier"].startswith(app_info["CFBundleIdentifier"] + "."):
        raise ValueError("The tunnel identifier does not belong to the application.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hidnet-ipa-") as work:
        temporary = Path(work)
        app = temporary / "Payload/HiDnet.app"
        shutil.copytree(source, app, symlinks=True)
        if ad_hoc_sign:
            sign_for_resigning(app, app / "PlugIns/HiDnetTunnel.appex", temporary)
        with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".ipa", delete=False) as stream:
            staged_output = Path(stream.name)
        try:
            with zipfile.ZipFile(staged_output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as ipa:
                for path in sorted((temporary / "Payload").rglob("*")):
                    name = path.relative_to(temporary).as_posix()
                    if path.is_symlink():
                        entry = zipfile.ZipInfo(name)
                        entry.create_system = 3
                        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                        ipa.writestr(entry, os.readlink(path))
                    else:
                        ipa.write(path, name)
            with zipfile.ZipFile(staged_output) as ipa:
                required = [
                    "Payload/HiDnet.app/Info.plist",
                    "Payload/HiDnet.app/" + app_info["CFBundleExecutable"],
                    "Payload/HiDnet.app/PlugIns/HiDnetTunnel.appex/Info.plist",
                    "Payload/HiDnet.app/PlugIns/HiDnetTunnel.appex/" + tunnel_info["CFBundleExecutable"],
                ]
                if any(name not in ipa.namelist() for name in required) or ipa.testzip() is not None:
                    raise ValueError("IPA verification failed.")
            staged_output.replace(output)
        finally:
            staged_output.unlink(missing_ok=True)
    digest = hashlib.sha256()
    with output.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    output.with_suffix(output.suffix + ".sha256").write_text(digest.hexdigest() + "  " + output.name + "\n")
    print("Created " + str(output))
    print("This IPA requires Apple provisioning and re-signing before installation.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, default=ROOT / "build/HiDnet.xcarchive")
    parser.add_argument("--output", type=Path, default=ROOT / "build/HiDnet.ipa")
    parser.add_argument("--ad-hoc-sign", action="store_true",
                        help="Embed requested entitlements with a local ad-hoc signature for SideStore to read.")
    args = parser.parse_args()
    try:
        package(args.archive.resolve(), args.output.resolve(), args.ad_hoc_sign)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, "IPA packaging failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
