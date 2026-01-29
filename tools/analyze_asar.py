#!/usr/bin/env python3
import struct

def analyze_asar(filename):
    with open(filename, 'rb') as f:
        print(f"Analyzing: {filename}\n")

        # Read first 16 bytes
        data = f.read(16)

        pickle_size = struct.unpack('<I', data[0:4])[0]
        field2 = struct.unpack('<I', data[4:8])[0]
        field3 = struct.unpack('<I', data[8:12])[0]
        field4 = struct.unpack('<I', data[12:16])[0]

        print(f"Offset 0-3   (pickle size):     {pickle_size} (0x{pickle_size:08x})")
        print(f"Offset 4-7   (field 2):          {field2} (0x{field2:08x})")
        print(f"Offset 8-11  (field 3):          {field3} (0x{field3:08x})")
        print(f"Offset 12-15 (field 4):          {field4} (0x{field4:08x})")

        print(f"\nDifferences:")
        print(f"field2 - field3 = {field2 - field3}")
        print(f"field3 - field4 = {field3 - field4}")

        # Read some JSON to see where it starts
        f.seek(16)
        json_start = f.read(100).decode('utf-8', errors='ignore')
        print(f"\nJSON starts at offset 16:")
        print(f"{json_start[:80]}...")

        # Calculate data offset
        data_offset = 16 + field2
        print(f"\nCalculated data offset (16 + field2): {data_offset}")

        f.seek(data_offset)
        file_data_start = f.read(20)
        print(f"Data at offset {data_offset}: {file_data_start[:20].hex()}")

if __name__ == '__main__':
    print("=== ORIGINAL ASAR ===")
    analyze_asar('/tmp/app.asar')
    print("\n\n=== PACKED ASAR ===")
    analyze_asar('/tmp/app-modified.asar')
