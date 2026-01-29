#!/usr/bin/env python3
import struct
import json
import sys

def read_asar_header(filename):
    with open(filename, 'rb') as f:
        # Skip first 4 bytes
        f.read(4)

        # Read header size
        header_size_bytes = f.read(4)
        header_size = struct.unpack('<I', header_size_bytes)[0]

        # Read alignment bytes
        f.read(8)

        # Read JSON header
        json_header = f.read(header_size)
        # Strip null bytes
        json_str = json_header.split(b'\x00')[0].decode('utf-8')
        header_data = json.loads(json_str)

        return header_data

def list_files(header, prefix=""):
    """Recursively list all files in the ASAR"""
    if 'files' in header:
        for name, info in header['files'].items():
            full_path = f"{prefix}/{name}" if prefix else name
            if 'files' in info:
                # It's a directory
                list_files(info, full_path)
            else:
                # It's a file
                size = info.get('size', 0)
                print(f"{full_path} ({size} bytes)")

if __name__ == '__main__':
    header = read_asar_header('/tmp/app.asar')
    list_files(header)
