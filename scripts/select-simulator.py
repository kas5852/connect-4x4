#!/usr/bin/env python3
"""Select an installed simulator instead of pinning a brittle device/OS name."""
import json
import subprocess

data = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
phones = [device for runtime, devices in data["devices"].items() if "iOS" in runtime
          for device in devices if device.get("isAvailable") and "iPhone" in device["name"]]
if not phones:
    raise SystemExit("No installed iPhone simulator runtime available")
print("udid=" + phones[0]["udid"])
