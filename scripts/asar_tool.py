#!/usr/bin/env python3
"""
Complete ASAR archive tool - extract and pack
Based on Electron ASAR format specification

Note: "pickle" in the ASAR format refers to a header size field,
not Python's pickle module. This tool only handles JSON data.
"""
import struct
import json
import os
import sys
import shutil


def read_asar_header(f):
    """Read and parse ASAR header"""
    # Read header size field (called "pickle" in ASAR spec, but it's just a uint32)
    size_bytes = f.read(4)
    if len(size_bytes) < 4:
        raise ValueError("Invalid ASAR file: too short")
    size_field = struct.unpack('<I', size_bytes)[0]

    # Read header size (4 bytes)
    header_size_bytes = f.read(4)
    header_size = struct.unpack('<I', header_size_bytes)[0]

    # Read header object size (4 bytes)
    header_obj_size_bytes = f.read(4)
    header_obj_size = struct.unpack('<I', header_obj_size_bytes)[0]

    # Read header flags (4 bytes)
    header_flags = f.read(4)

    # Read JSON header (safe format, not pickle)
    json_bytes = f.read(header_size - 8)
    null_idx = json_bytes.find(b'\x00')
    if null_idx != -1:
        json_bytes = json_bytes[:null_idx]

    header = json.loads(json_bytes.decode('utf-8'))

    # Calculate base offset for file data
    base_offset = 16 + header_size - 8

    return header, base_offset


def extract_file(f, file_info, base_offset, output_path):
    """Extract a single file from ASAR"""
    offset = int(file_info.get('offset', 0))
    size = int(file_info.get('size', 0))

    # Seek to file data
    f.seek(base_offset + offset)
    data = f.read(size)

    # Write to output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as out:
        out.write(data)


def extract_directory(f, dir_info, base_offset, output_dir):
    """Recursively extract directory"""
    files = dir_info.get('files', {})

    for name, info in files.items():
        output_path = os.path.join(output_dir, name)

        if 'files' in info:
            # It's a directory
            os.makedirs(output_path, exist_ok=True)
            extract_directory(f, info, base_offset, output_path)
        else:
            # It's a file
            extract_file(f, info, base_offset, output_path)


def extract_asar(asar_path, output_dir):
    """Extract entire ASAR archive"""
    with open(asar_path, 'rb') as f:
        header, base_offset = read_asar_header(f)

        # Extract root directory
        extract_directory(f, header, base_offset, output_dir)


def build_header(root_dir):
    """Build ASAR header from directory structure"""
    def scan_dir(path):
        files = {}
        entries = sorted(os.listdir(path))

        for entry in entries:
            full_path = os.path.join(path, entry)

            if os.path.isdir(full_path):
                files[entry] = scan_dir(full_path)
            else:
                stat = os.stat(full_path)
                files[entry] = {
                    'size': stat.st_size,
                    'offset': 0  # Will be calculated during packing
                }

        return {'files': files}

    return scan_dir(root_dir)


def calculate_offsets(header, current_offset=0):
    """Calculate file offsets in the packed archive"""
    files = header.get('files', {})

    for name, info in files.items():
        if 'files' in info:
            # Directory
            current_offset = calculate_offsets(info, current_offset)
        else:
            # File
            info['offset'] = str(current_offset)
            current_offset += info['size']

    return current_offset


def write_files(f, root_dir, header):
    """Write file contents to ASAR"""
    files = header.get('files', {})

    for name, info in sorted(files.items()):
        full_path = os.path.join(root_dir, name)

        if 'files' in info:
            # Directory
            write_files(f, full_path, info)
        else:
            # File
            with open(full_path, 'rb') as file_in:
                data = file_in.read()
                f.write(data)


def pack_asar(input_dir, output_asar):
    """Pack directory into ASAR archive"""
    # Build header
    header = build_header(input_dir)

    # Calculate offsets
    calculate_offsets(header)

    # Serialize header as JSON (safe format)
    header_json = json.dumps(header, separators=(',', ':')).encode('utf-8')
    header_json += b'\x00'  # Null terminator

    # Calculate sizes
    header_size = len(header_json) + 8  # +8 for header_obj_size and flags
    header_obj_size = len(header_json)

    # Align to 4-byte boundary
    padding = (4 - (header_size % 4)) % 4
    header_json += b'\x00' * padding
    header_size += padding

    # Write ASAR file
    with open(output_asar, 'wb') as f:
        # Size field (4 bytes) - always 4 in ASAR spec
        f.write(struct.pack('<I', 4))

        # Header size (includes the size fields)
        f.write(struct.pack('<I', header_size))

        # Header object size
        f.write(struct.pack('<I', header_obj_size))

        # Header flags (4 bytes of zeros)
        f.write(struct.pack('<I', 0))

        # JSON header
        f.write(header_json)

        # File contents
        write_files(f, input_dir, header)


def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print(f"  {sys.argv[0]} extract <asar_file> <output_dir>")
        print(f"  {sys.argv[0]} pack <input_dir> <output_asar>")
        sys.exit(1)

    command = sys.argv[1]

    if command == 'extract':
        if len(sys.argv) != 4:
            print("Usage: extract <asar_file> <output_dir>")
            sys.exit(1)
        asar_path = sys.argv[2]
        output_dir = sys.argv[3]
        print(f"Extracting {asar_path} to {output_dir}...")
        extract_asar(asar_path, output_dir)
        print("Done!")

    elif command == 'pack':
        if len(sys.argv) != 4:
            print("Usage: pack <input_dir> <output_asar>")
            sys.exit(1)
        input_dir = sys.argv[2]
        output_asar = sys.argv[3]
        print(f"Packing {input_dir} to {output_asar}...")
        pack_asar(input_dir, output_asar)
        print("Done!")

    else:
        print(f"Unknown command: {command}")
        print("Valid commands: extract, pack")
        sys.exit(1)


if __name__ == '__main__':
    main()
