#!/usr/bin/env python3
"""Make PKCS#12 identities selectable in the physical-device Files picker.

Some Files providers advertise .p12/.pfx documents with provider-specific or
undeclared UTTypes. Filtering the picker with a dynamically-created UTType can
therefore display an identity while refusing selection. Accept a generic item
at the picker boundary and leave the host's existing extension validation in
place before the file is read.
"""

from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: apply_certificate_import_fix.py <VibeContainers-root>", file=sys.stderr)
        return 2

    settings = Path(sys.argv[1]) / "iOSSim/Apps/SettingsApp.swift"
    source = settings.read_text()
    old = '''        .fileImporter(
            isPresented: $importingCertificate,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType(filenameExtension: "pfx") ?? .data
            ]
        ) { result in
            selectCertificate(result)
        }
'''
    new = '''        .fileImporter(
            isPresented: $importingCertificate,
            // Files providers do not consistently declare PKCS#12 UTTypes.
            // Accept selection here; selectCertificate strictly gates .p12/.pfx.
            allowedContentTypes: [.item]
        ) { result in
            selectCertificate(result)
        }
'''

    if new in source:
        print(f"certificate import fix already present in {settings}")
        return 0
    if old not in source:
        print(f"refusing to patch unexpected certificate importer in {settings}", file=sys.stderr)
        return 1

    source = source.replace(old, new, 1)
    if 'guard ext == "p12" || ext == "pfx" else {' not in source:
        print("certificate extension validation is missing", file=sys.stderr)
        return 1
    settings.write_text(source)
    print(f"patched {settings}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
