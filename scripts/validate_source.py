#!/usr/bin/env python3
"""Static sanity checks only. Does not compile Swift or replace Xcode tests.
Optional requirements: pip install tree-sitter tree-sitter-swift openstep-parser
"""
from pathlib import Path
import json
import plistlib
import xml.etree.ElementTree as ET
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder

root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
errors = []
sources = list(root.rglob('*.swift'))
for path in sources:
    tree = parser.parse(path.read_bytes())
    pending = [tree.root_node]
    while pending:
        node = pending.pop()
        if node.type == 'ERROR' or node.is_missing:
            errors.append(f'{path.relative_to(root)}:{node.start_point.row+1}: {node.type}')
        pending.extend(node.children)
assert not errors, '\n'.join(errors)
print(f'PASS: syntax parsed for {len(sources)} Swift files (not type-checked)')
project = OpenStepDecoder.ParseFromString((root/'Clearspace.xcodeproj/project.pbxproj').read_text())
objects = project['objects']
referenced_sources = set()
for value in objects.values():
    if value['isa'] == 'PBXFileReference' and value.get('sourceTree') == 'SOURCE_ROOT':
        assert (root/value['path']).exists(), value['path']
        if value['path'].endswith('.swift'): referenced_sources.add(value['path'])
assert referenced_sources == {str(p.relative_to(root)) for p in sources}
for value in objects.values():
    if value['isa'] == 'PBXBuildFile': assert value['fileRef'] in objects
    for field in ('buildPhases','buildConfigurations','targets','children','dependencies'):
        for ref in value.get(field,[]): assert ref in objects, (field,ref)
print(f'PASS: {len(objects)} Xcode objects and all Swift source references')
for path in [root/'Clearspace/Info.plist', root/'Clearspace/PrivacyInfo.xcprivacy']:
    plistlib.loads(path.read_bytes())
for path in root.rglob('*.json'): json.loads(path.read_text())
ET.parse(root/'Clearspace.xcodeproj/xcshareddata/xcschemes/Clearspace.xcscheme')
print('PASS: property lists, asset JSON and scheme XML')
all_source = '\n'.join(p.read_text() for p in sources)
assert all_source.count('PHAssetChangeRequest.deleteAssets(') == 1
assert 'isNetworkAccessAllowed = true' not in all_source
assert 'URLSession' not in all_source
assert 'value(forKey:' not in all_source
print('PASS: single deletion site, no enabled downloads / URLSession / private file-size lookup')
print('NOT RUN: Apple SDK type-check, Xcode build, XCTest, UI tests, real iPhone tests')
