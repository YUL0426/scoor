"""Validate PNG headers/chunks, then package the five submission images."""
from pathlib import Path
import hashlib
import json
import struct
import zipfile

root = Path(__file__).resolve().parents[1]
expected = {"iphone-6.9": (1320, 2868, 5)}
results = []
for device, (width, height, count) in expected.items():
    files = sorted((root / "upload" / "ko-KR" / device).glob("*.png"))
    assert len(files) == count, (device, len(files))
    for path in files:
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        w, h, depth, mode = struct.unpack(">IIBB", data[16:26])
        assert (w, h) == (width, height), path
        assert depth == 8 and mode == 2, (path, depth, mode)
        pos, chunks = 8, []
        while pos < len(data):
            length = struct.unpack(">I", data[pos:pos+4])[0]
            kind = data[pos+4:pos+8].decode("ascii")
            chunks.append(kind)
            pos += 12 + length
        assert "tRNS" not in chunks
        assert "sRGB" in chunks or "iCCP" in chunks, (path, chunks)
        results.append({"file": str(path.relative_to(root)), "width": w, "height": h,
                        "bit_depth": depth, "color_type": "RGB", "alpha": False,
                        "profile_chunk": "sRGB" if "sRGB" in chunks else "iCCP",
                        "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})

report = {"date": "2026-09-11", "status": "passed", "file_count": len(results), "files": results}
(root / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
archive = root / "Scoor-AppStore-World-ko-KR.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as z:
    for item in results:
        z.write(root / item["file"], item["file"])
    z.write(root / "README.md", "README.md")
    z.write(root / "validation.json", "validation.json")
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
print(json.dumps({"status": "passed", "images": len(results), "zip": str(archive)}, ensure_ascii=False))
