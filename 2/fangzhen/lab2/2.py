import struct

def disassemble_bin(filename, start_offset, num=10):
    with open(filename, 'rb') as f:
        f.seek(start_offset)
        for i in range(num):
            data = f.read(4)
            if len(data) < 4:
                break
            addr = 0x80000000 + start_offset + i * 4
            inst = struct.unpack('<I', data)[0]
            print(f"0x{addr:08X}: 0x{inst:08X}")

disassemble_bin("fangzhen\\lab2\\lab2.bin", 0x90, 10)

with open("fangzhen\\lab2\\lab2.bin", "rb") as f:
    f.seek(0x94)
    inst = struct.unpack('<I', f.read(4))[0]
    print(f"0x80000094: 0x{inst:08X}")