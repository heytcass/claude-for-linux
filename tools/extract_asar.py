#!/usr/bin/env python3
import struct
import json
import sys

def read_asar_header(filename):
    with open(filename, 'rb') as f:
        # Read ASAR header
        # First 4 bytes: header size (UInt32LE)
        # Next 4 bytes: JSON size (UInt32LE)
        # Next 4 bytes: JSON data size (UInt32LE) or alignment
        # Then JSON header data

        # Skip first 4 bytes (pickle size / legacy)
        f.read(4)

        # Read header size
        header_size_bytes = f.read(4)
        header_size = struct.unpack('<I', header_size_bytes)[0]

        # Read alignment bytes
        f.read(8)

        # Read JSON header
        json_header = f.read(header_size)
        # Strip null bytes and extra data
        json_str = json_header.split(b'\x00')[0].decode('utf-8')
        header_data = json.loads(json_str)

        return header_data

def find_file_in_asar(header, target_path):
    """Find a file in the ASAR header structure"""
    parts = target_path.strip('/').split('/')
    current = header

    for part in parts:
        if 'files' not in current:
            return None
        if part not in current['files']:
            return None
        current = current['files'][part]

    return current

def extract_file_from_asar(filename, target_path):
    header = read_asar_header(filename)
    file_info = find_file_in_asar(header, target_path)

    if not file_info or 'offset' not in file_info:
        print(f"File {target_path} not found in ASAR", file=sys.stderr)
        return None

    offset = int(file_info['offset'])
    size = int(file_info['size'])

    # Calculate actual offset: skip past header
    with open(filename, 'rb') as f:
        f.read(4)  # Skip legacy
        header_size_bytes = f.read(4)
        header_size = struct.unpack('<I', header_size_bytes)[0]
        f.read(8)  # Skip alignment

        # Base offset for files is after header
        base_offset = 4 + 4 + 8 + header_size

        f.seek(base_offset + offset)
        return f.read(size)

if __name__ == '__main__':
    data = extract_file_from_asar('/tmp/app.asar', 'package.json')
    if data:
        print(data.decode('utf-8'))
