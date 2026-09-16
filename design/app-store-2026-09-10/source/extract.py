"""Copy only named marketing captures from an xcresult attachment export."""
import json
import pathlib
import re
import shutil
import sys

source, destination = map(pathlib.Path, sys.argv[1:3])
manifest = json.loads((source / "manifest.json").read_text())
destination.mkdir(parents=True, exist_ok=True)
found = set()

def walk(value):
    if isinstance(value, dict):
        name = value.get("suggestedHumanReadableName", "")
        filename = value.get("exportedFileName", "")
        match = re.match(r"store-ko-(\d\d-[a-z]+)_", name)
        if match and filename.endswith(".png"):
            slug = match.group(1)
            shutil.copy2(source / filename, destination / f"{slug}.png")
            found.add(slug)
            print(f"{slug}.png <- {filename}")
        for child in value.values():
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)

walk(manifest)
print(f"Extracted {len(found)} capture(s)")
if len(found) != 4:
    sys.exit("Expected exactly four named Korean screenshots")
