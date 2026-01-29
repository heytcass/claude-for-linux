#!/usr/bin/env python3
"""
Modify an ASAR archive by adding files to it.
This is a simplified implementation that can add files to existing ASAR archives.
"""
import struct
import json
import os
import sys

def read_asar(filename):
    """Read ASAR file and return header and data offset"""
    with open(filename, 'rb') as f:
        # Read pickle size (4 bytes, always 4)
        pickle_size = struct.unpack('<I', f.read(4))[0]

        # Read header size
        header_size = struct.unpack('<I', f.read(4))[0]

        # Read alignment (8 bytes)
        f.read(8)

        # Read JSON header
        json_header = f.read(header_size)
        json_str = json_header.split(b'\x00')[0].decode('utf-8')
        header = json.loads(json_str)

        # Calculate data offset
        data_offset = 16 + header_size

        # Read all file data
        f.seek(data_offset)
        file_data = f.read()

        return header, file_data, data_offset

def add_files_to_header(header, files_to_add, current_offset=0):
    """Add files to the ASAR header structure"""
    if 'files' not in header:
        header['files'] = {}

    for file_path, file_content in files_to_add.items():
        parts = file_path.strip('/').split('/')
        current = header

        # Navigate/create directory structure
        for i, part in enumerate(parts[:-1]):
            if 'files' not in current:
                current['files'] = {}
            if part not in current['files']:
                current['files'][part] = {'files': {}}
            current = current['files'][part]

        # Add the file
        if 'files' not in current:
            current['files'] = {}

        filename = parts[-1]
        current['files'][filename] = {
            'size': len(file_content),
            'offset': str(current_offset)
        }
        current_offset += len(file_content)

    return header, current_offset

def get_total_size(header):
    """Calculate total data size from header"""
    total = 0

    def traverse(node):
        nonlocal total
        if 'files' in node:
            for name, info in node['files'].items():
                if 'offset' in info:
                    total = max(total, int(info['offset']) + int(info['size']))
                else:
                    traverse(info)

    traverse(header)
    return total

def write_asar(filename, header, file_data, new_files):
    """Write a new ASAR file"""
    # Serialize header
    header_json = json.dumps(header, separators=(',', ':')).encode('utf-8')
    header_size = len(header_json)

    # Pad header to 4-byte boundary
    padding = (4 - (header_size % 4)) % 4
    header_json += b'\x00' * padding
    header_size_padded = len(header_json)

    # Write ASAR file
    with open(filename, 'wb') as f:
        # Write pickle size (always 4)
        f.write(struct.pack('<I', 4))

        # Write header size
        f.write(struct.pack('<I', header_size_padded))

        # Write alignment (8 bytes of zeros)
        f.write(b'\x00' * 8)

        # Write header
        f.write(header_json)

        # Write original file data
        f.write(file_data)

        # Write new files
        for file_path in sorted(new_files.keys()):
            f.write(new_files[file_path])

if __name__ == '__main__':
    # Read original ASAR
    print("Reading original ASAR...")
    header, file_data, data_offset = read_asar('/tmp/app.asar')
    original_size = get_total_size(header)
    print(f"Original data size: {original_size} bytes")

    # Prepare files to add
    i18n_dir = '/tmp/claude-extracted/Claude/Claude.app/Contents/Resources'
    new_files = {}

    for filename in os.listdir(i18n_dir):
        if filename.endswith('.json'):
            file_path = os.path.join(i18n_dir, filename)
            with open(file_path, 'rb') as f:
                content = f.read()
            new_files[f'resources/i18n/{filename}'] = content
            print(f"Adding: resources/i18n/{filename} ({len(content)} bytes)")

    # Add files to header
    print("\nUpdating header...")
    header, new_offset = add_files_to_header(header, new_files, original_size)

    # Write new ASAR
    print(f"\nWriting modified ASAR to /tmp/app-modified.asar...")
    write_asar('/tmp/app-modified.asar', header, file_data, new_files)

    print("Done!")
    print(f"Original size: {os.path.getsize('/tmp/app.asar')} bytes")
    print(f"Modified size: {os.path.getsize('/tmp/app-modified.asar')} bytes")
