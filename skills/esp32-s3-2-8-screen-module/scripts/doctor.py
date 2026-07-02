#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

REPO_SENTINELS = (
    "ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/main.c",
    "Firmware/ESP32-S3-2.8-Image-Test.bin",
)


def _is_repo_root(path: Path) -> bool:
    return all((path / marker).exists() for marker in REPO_SENTINELS)


def _search_upwards(start: Path) -> Path | None:
    for candidate in (start, *start.parents):
        if _is_repo_root(candidate):
            return candidate
    return None


def resolve_repo_root(explicit: str | None) -> Path | None:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser().resolve())

    env_repo = os.environ.get("ESP32_S3_TOUCH_LCD_REPO")
    if env_repo:
        candidates.append(Path(env_repo).expanduser().resolve())

    candidates.append(Path.cwd().resolve())
    candidates.append(Path(__file__).resolve().parent)

    for candidate in candidates:
        match = _search_upwards(candidate)
        if match is not None:
            return match
    return None


def find_tool(name: str) -> str | None:
    return shutil.which(name)


def discover_idf_exports(system_name: str) -> list[str]:
    export_name = "export.ps1" if system_name == "Windows" else "export.sh"
    candidates: list[Path] = []
    idf_path = os.environ.get("IDF_PATH")
    if idf_path:
        candidates.append(Path(idf_path).expanduser() / export_name)

    home = Path.home()
    patterns = (
        f"esp/**/esp-idf/{export_name}",
        f"espidf/**/esp-idf/{export_name}",
    )
    for pattern in patterns:
        candidates.extend(home.glob(pattern))

    idf_env = home / ".espressif/idf-env.json"
    try:
        installed = json.loads(idf_env.read_text()).get("idfInstalled", {})
        for value in installed.values():
            path = value.get("path")
            if path:
                candidates.append(Path(path).expanduser() / export_name)
    except (OSError, ValueError, AttributeError):
        pass

    unique = {str(path.resolve()) for path in candidates if path.is_file()}
    return sorted(unique, key=lambda value: ("5.4" not in value, value))


def has_python_module(module_name: str) -> bool:
    return importlib.util.find_spec(module_name) is not None


def detect_windows_ports() -> list[str]:
    ports: set[str] = set()

    try:
        result = subprocess.run(
            ["cmd", "/c", "mode"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        ports.update(re.findall(r"(COM\d+):", result.stdout))
    except OSError:
        pass

    try:
        from serial.tools import list_ports  # type: ignore

        for port in list_ports.comports():
            ports.add(port.device)
    except Exception:
        pass

    return sorted(ports, key=lambda value: int(re.sub(r"\D", "", value) or "0"))


def detect_posix_ports(patterns: tuple[str, ...]) -> list[str]:
    ports: set[str] = set()
    for pattern in patterns:
        for match in Path("/").glob(pattern.lstrip("/")):
            ports.add(str(match))
    return sorted(ports)


def detect_serial_ports(system_name: str) -> list[str]:
    if system_name == "Windows":
        return detect_windows_ports()
    if system_name == "Darwin":
        return detect_posix_ports(
            (
                "/dev/cu.usbmodem*",
                "/dev/cu.usbserial*",
                "/dev/cu.wchusbserial*",
                "/dev/tty.usbmodem*",
                "/dev/tty.usbserial*",
                "/dev/tty.wchusbserial*",
            )
        )
    return detect_posix_ports(("/dev/ttyUSB*", "/dev/ttyACM*"))


def build_report(repo_root: Path | None) -> dict[str, object]:
    system_name = platform.system()
    idf_path = os.environ.get("IDF_PATH")
    idf_installations = discover_idf_exports(system_name)
    python_cmd = find_tool("python3") or find_tool("python") or find_tool("py")
    report: dict[str, object] = {
        "platform": {
            "system": system_name,
            "release": platform.release(),
        },
        "repo_root": str(repo_root) if repo_root else None,
        "paths": {},
        "tools": {
            "idf.py": find_tool("idf.py"),
            "esptool.py": find_tool("esptool.py"),
            "eim": find_tool("eim"),
            "python": python_cmd,
            "IDF_PATH": idf_path,
        },
        "idf_installations": idf_installations,
        "usable_idf_export": idf_installations[0] if idf_installations else None,
        "python_modules": {
            "yaml": has_python_module("yaml"),
            "serial": has_python_module("serial"),
            "esptool": has_python_module("esptool"),
        },
        "serial_ports": detect_serial_ports(system_name),
        "recommended_actions": [],
    }

    if repo_root is not None:
        report["paths"] = {
            "idf_project": str(repo_root / "ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test"),
            "first_boot_firmware": str(repo_root / "Firmware/ESP32-S3-2.8-Image-Test.bin"),
            "skill_dir": str(repo_root / "skills/esp32-s3-2-8-screen-module"),
        }
    else:
        report["recommended_actions"].append(
            "Set --repo-root or ESP32_S3_TOUCH_LCD_REPO so the scripts can locate the vendor project."
        )

    if not report["tools"]["idf.py"] and idf_installations:
        report["recommended_actions"].append(
            "Activate the existing ESP-IDF with usable_idf_export; do not install another copy."
        )
    elif not report["tools"]["idf.py"]:
        report["recommended_actions"].append(
            "No existing ESP-IDF installation was found. Bootstrap is needed only before a requested source build."
        )

    if not report["tools"]["esptool.py"] and not report["tools"]["python"]:
        report["recommended_actions"].append(
            "Install esptool.py or make python available before flashing the first-boot image firmware."
        )

    if not report["tools"]["eim"] and not idf_installations:
        report["recommended_actions"].append(
            "Install Espressif Installation Manager so ESP-IDF can be provisioned automatically."
        )

    missing_modules = [
        name for name, present in report["python_modules"].items() if not present
    ]
    if missing_modules:
        report["recommended_actions"].append(
            "Install Python helper packages for: " + ", ".join(sorted(missing_modules)) + "."
        )

    if not report["serial_ports"]:
        report["recommended_actions"].append(
            "Connect the board and re-run the doctor script so a serial port is available for flashing."
        )

    if not report["recommended_actions"]:
        report["recommended_actions"].append("Environment looks ready for build/flash work.")

    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect this ESP32-S3 2.8-inch screen module workspace.")
    parser.add_argument("--repo-root", help="Explicit repository root for the vendor sample.")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON output.")
    args = parser.parse_args()

    repo_root = resolve_repo_root(args.repo_root)
    report = build_report(repo_root)

    if args.json:
        print(json.dumps(report, indent=2))
        return 0

    print(f"system: {report['platform']['system']} {report['platform']['release']}")
    print(f"repo_root: {report['repo_root'] or 'not found'}")
    print(f"idf.py: {report['tools']['idf.py'] or 'missing'}")
    print(f"esptool.py: {report['tools']['esptool.py'] or 'missing'}")
    print(f"eim: {report['tools']['eim'] or 'missing'}")
    print(f"python: {report['tools']['python'] or 'missing'}")
    print(f"usable_idf_export: {report['usable_idf_export'] or 'not found'}")
    print("python_modules:")
    for name, present in report["python_modules"].items():
        print(f"  - {name}: {'ok' if present else 'missing'}")
    print("serial_ports:")
    for port in report["serial_ports"]:
        print(f"  - {port}")
    if not report["serial_ports"]:
        print("  - none detected")
    print("recommended_actions:")
    for action in report["recommended_actions"]:
        print(f"  - {action}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
