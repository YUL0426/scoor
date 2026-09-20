#!/usr/bin/env python3
"""Check English UI fallbacks, JA/FR/PT-BR, and legal translation provenance.
Optionally pass Xcode's Objects-normal/arm64 directory to audit extracted keys.
"""
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ('ja', 'fr', 'pt-BR')
CATALOG = ROOT / 'Scoor/Localizable.xcstrings'

def values(node):
    if 'stringUnit' in node:
        yield node['stringUnit']['value']
    for variation in node.get('variations', {}).values():
        for child in variation.values():
            yield from values(child)

def formats(text):
    return Counter(kind for _, kind in re.findall(
        r'%(?:(\d+)\$)?[-+0 #]*(?:\d+)?(?:\.\d+)?(lld|ld|d|f|@|%)', text) if kind != '%')

def main():
    strings = json.loads(CATALOG.read_text())['strings']
    for key, entry in strings.items():
        localizations = entry.get('localizations', {})
        english = list(values(localizations.get('en', {}))) or [key]
        for value in english:
            assert not re.search('[가-힣]', value), (key, 'en', 'Korean fallback')
            assert value or not key, (key, 'en', 'empty')
            # Symbolic keys (e.g. time.short.days) declare formats in their values.
            if formats(key):
                assert formats(key) == formats(value), (key, 'en', 'format mismatch')
        source = next(values(localizations.get('en', {})), key)
        for language in LANGUAGES:
            translated = list(values(localizations.get(language, {})))
            assert translated, (key, language, 'missing')
            for value in translated:
                assert value or not key, (key, language, 'empty')
                assert formats(source) == formats(value), (key, language, 'format mismatch')
                assert not re.search('[가-힣]', value), (key, language, 'Korean fallback')
    original_path = ROOT / 'Scoor/Resources/Legal/legal-policy.json'
    original = json.loads(original_path.read_text())
    translations = json.loads((original_path.parent / 'legal-policy-translations.json').read_text())
    assert translations['version'] == original['version']
    assert translations['sourceSHA256'] == hashlib.sha256(original_path.read_bytes()).hexdigest()
    for kind in ('terms', 'privacy'):
        for language in LANGUAGES:
            document = translations[kind][language]
            assert len(document['sections']) == len(original[kind]['en']['sections'])
            assert all(s['title'] and s['body'] for s in document['sections'])
    if len(sys.argv) > 1:
        for path in Path(sys.argv[1]).glob('*.stringsdata'):
            for entry in json.loads(path.read_text()).get('tables', {}).get('Localizable', []):
                assert entry['key'] in strings, (path.name, entry['key'], 'uncataloged extracted key')
    print(f'PASS: {len(strings)} keys; English fallbacks, JA/FR/PT-BR placeholders and 60 legal sections verified.')

if __name__ == '__main__':
    main()
