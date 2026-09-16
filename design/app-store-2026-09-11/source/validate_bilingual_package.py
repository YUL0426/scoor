"""Validate both locales sequentially and package without recompressing PNGs."""
from pathlib import Path
import hashlib
import json
import struct
import zipfile

root = Path(__file__).resolve().parents[1]
previous = json.loads((root / "validation.json").read_text())
original_hashes = {item["file"]: item["sha256"] for item in previous["files"]}
results = []
for locale in ("ko-KR", "en-US"):
    files = sorted((root / "upload" / locale / "iphone-6.9").glob("*.png"))
    assert len(files) == 5, (locale, len(files))
    for path in files:
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", path
        width, height, depth, mode = struct.unpack(">IIBB", data[16:26])
        assert (width, height, depth, mode) == (1320, 2868, 8, 2), path
        pos, chunks = 8, []
        while pos < len(data):
            length = struct.unpack(">I", data[pos:pos+4])[0]
            chunks.append(data[pos+4:pos+8].decode("ascii"))
            pos += 12 + length
        assert "tRNS" not in chunks, path
        assert "sRGB" in chunks or "iCCP" in chunks, path
        relative = str(path.relative_to(root))
        digest = hashlib.sha256(data).hexdigest()
        if locale == "ko-KR":
            assert original_hashes[relative] == digest, "Domestic image changed"
        results.append({"file": relative, "locale": locale, "width": width, "height": height,
                        "bit_depth": depth, "color_type": "RGB", "alpha": False,
                        "profile_chunk": "sRGB" if "sRGB" in chunks else "iCCP",
                        "bytes": len(data), "sha256": digest})

report = {"date": "2026-09-11", "status": "passed", "file_count": len(results),
          "domestic_originals_unchanged": True, "files": results}
(root / "validation-bilingual.json").write_text(json.dumps(report, indent=2) + "\n")
archives = []
for suffix, selected in (("en-US", [i for i in results if i["locale"] == "en-US"]),
                         ("ko-KR-en-US", results)):
    archive = root / f"Scoor-AppStore-World-{suffix}.zip"
    manifest = dict(report, file_count=len(selected), files=selected)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as package:
        for item in selected:
            package.write(root / item["file"], item["file"])
        package.write(root / "UPLOAD-KR-EN.md", "UPLOAD-KR-EN.md")
        package.writestr("validation.json", json.dumps(manifest, indent=2) + "\n")
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        assert len([n for n in package.namelist() if n.endswith(".png")]) == len(selected)
    archives.append(str(archive))
print(json.dumps({"status": "passed", "images": len(results),
                  "domestic_originals_unchanged": True, "archives": archives}))
