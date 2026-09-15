"""Golden instruction tests first; then compare every named ROM against its assembly."""
from pathlib import Path
import unittest
from rv32_encoder import mem_text
import test_encoder
def main():
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(test_encoder))
    if not result.wasSuccessful(): raise SystemExit(1)
    root=Path(__file__).resolve().parents[1]
    for asm in sorted((root/"asm").glob("*.S")):
        mem=root/"mem"/(asm.stem+".mem")
        if not mem.exists() or mem.read_text()!=mem_text(asm.read_text(encoding="utf-8")):
            raise SystemExit("ROM mismatch: "+str(mem))
        print("MEM_MATCH",mem.name)
    print("ENCODER_GOLDEN_PASS")
if __name__=="__main__": main()
