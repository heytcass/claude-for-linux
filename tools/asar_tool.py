#!/usr/bin/env python3
"""
Complete ASAR archive tool - extract and pack
Based on Electron ASAR format specification
"""
import struct
import json
import os
import sys
import shutil

def read_asar_header(f):
    """Read and parse ASAR header"""
    # Read pickle size (4 bytes)
    pickle_bytes = f.read(4)
    if len(pickle_bytes) < 4:
        raise ValueError("Invalid ASAR file: too short")
    pickle_size = struct.unpack('<I', pickle_bytes)[0]

    # Read header size (4 bytes)
    header_size_bytes = f.read(4)
    header_size = struct.unpack('<I', header_size_bytes)[0]

    # Read header object size (4 bytes)
    header_obj_size_bytes = f.read(4)
    header_obj_size = struct.unpack('<I', header_obj_size_bytes)[0]

    # Read header flags (4 bytes)
    header_flags = f.read(4)

    # Read JSON header
    json_bytes = f.read(header_size - 8)  # -8 for the two uint32s we already read
    # Find null terminator
    null_idx = json_bytes.find(b'\x00')
    if null_idx != -1:
        json_bytes = json_bytes[:null_idx]

    header = json.loads(json_bytes.decode('utf-8'))

    # Calculate base offset for file data
    base_offset = 16 + header_size - 8

    return header, base_offset

def extract_asar(asar_path, output_dir):
    """Extract entire ASAR archive"""
    with open(asar_path, 'rb') as f:
        header, base_offset = read_asar_header(f)

        # Navigate to data start
        f.seek(base_offset)
        all_data = f.read()

    # Extract files recursively
    def extract_node(node, current_path):
        if 'files' in node:
            for name, info in node['files'].items():
                full_path = os.path.join(current_path, name)
                if 'files' in info:
                    # Directory
                    os.makedirs(full_path, exist_ok=True)
                    extract_node(info, full_path)
                else:
                    # File
                    if 'offset' in info:
                        # Regular file packed in ASAR
                        offset = int(info['offset'])
                        size = int(info['size'])
                        file_data = all_data[offset:offset + size]

                        os.makedirs(current_path, exist_ok=True)
                        with open(full_path, 'wb') as out_f:
                            out_f.write(file_data)
                        print(f"Extracted: {full_path}")
                    elif 'unpacked' in info:
                        # File is in .unpacked directory, skip it
                        print(f"Skipped (unpacked): {full_path}")
                    elif 'link' in info:
                        # Symbolic link
                        print(f"Skipped (symlink): {full_path}")
                    else:
                        print(f"Warning: Unknown file type: {full_path}, info={info}")

    extract_node(header, output_dir)
    print(f"\nExtraction complete: {output_dir}")

def create_header_from_directory(dir_path):
    """Create ASAR header from directory structure"""
    def build_node(path):
        node = {}
        items = sorted(os.listdir(path))

        if items:
            node['files'] = {}

        for item in items:
            full_path = os.path.join(path, item)
            if os.path.isdir(full_path):
                node['files'][item] = build_node(full_path)
            else:
                # We'll add size and offset later
                node['files'][item] = {
                    '_file_path': full_path
                }

        return node

    return build_node(dir_path)

def pack_asar(source_dir, output_path):
    """Pack directory into ASAR archive"""
    # Build header structure
    print("Building header...")
    header = create_header_from_directory(source_dir)

    # Collect all files and assign offsets
    files_data = []
    current_offset = 0

    def assign_offsets(node):
        nonlocal current_offset
        if 'files' in node:
            for name, info in node['files'].items():
                if 'files' in info:
                    assign_offsets(info)
                elif '_file_path' in info:
                    file_path = info['_file_path']
                    with open(file_path, 'rb') as f:
                        data = f.read()

                    info['offset'] = str(current_offset)
                    info['size'] = len(data)
                    del info['_file_path']

                    files_data.append(data)
                    current_offset += len(data)

                    print(f"Adding: {file_path} (offset={info['offset']}, size={info['size']})")

    assign_offsets(header)

    # Serialize header
    header_json = json.dumps(header, separators=(',', ':')).encode('utf-8')
    header_size = len(header_json)

    # Calculate padding
    # Header size includes the 8 bytes for header_obj_size and flags
    total_header_size = header_size + 8
    # Pad to 4-byte boundary
    padding_needed = (4 - (total_header_size % 4)) % 4
    header_json += b'\x00' * padding_needed
    total_header_size_padded = total_header_size + padding_needed

    # Write ASAR
    print(f"\nWriting ASAR to {output_path}...")
    with open(output_path, 'wb') as f:
        # Pickle size (always 4)
        f.write(struct.pack('<I', 4))

        # field2: Header size (total size from offset 8 onwards, i.e., JSON + padding + 8 bytes)
        field2 = total_header_size_padded
        f.write(struct.pack('<I', field2))

        # field3: field2 - 4
        field3 = field2 - 4
        f.write(struct.pack('<I', field3))

        # field4: JSON size before padding
        field4 = header_size
        f.write(struct.pack('<I', field4))

        # Header JSON (already padded)
        f.write(header_json)

        # File data
        for data in files_data:
            f.write(data)

    print(f"Pack complete! Size: {os.path.getsize(output_path)} bytes")
    print(f"Header structure: field2={field2}, field3={field3}, field4={field4}")

    print(f"Pack complete! Size: {os.path.getsize(output_path)} bytes")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage:")
        print("  Extract: python3 asar_tool.py extract <asar_file> <output_dir>")
        print("  Pack:    python3 asar_tool.py pack <source_dir> <output_asar>")
        sys.exit(1)

    command = sys.argv[1]

    if command == 'extract':
        if len(sys.argv) != 4:
            print("Extract usage: python3 asar_tool.py extract <asar_file> <output_dir>")
            sys.exit(1)
        extract_asar(sys.argv[2], sys.argv[3])

    elif command == 'pack':
        if len(sys.argv) != 4:
            print("Pack usage: python3 asar_tool.py pack <source_dir> <output_asar>")
            sys.exit(1)
        pack_asar(sys.argv[2], sys.argv[3])

    else:
        print(f"Unknown command: {command}")
        print("Use 'extract' or 'pack'")
        sys.exit(1)
