"""Independent published-format RV32I encodings plus malformed-input checks."""
import unittest
from rv32_encoder import assemble, mem_text
class EncoderTests(unittest.TestCase):
    def test_golden(self):
        pairs = {
            "add t0,t1,t2":0x007302b3, "sub t0,t1,t2":0x407302b3,
            "slt t0,t1,t2":0x007322b3,"sltu t0,t1,t2":0x007332b3,
            "xor t0,t1,t2":0x007342b3,"or t0,t1,t2":0x007362b3,"and t0,t1,t2":0x007372b3,
            "addi a0,zero,-1":0xfff00513,"andi a0,a1,7":0x0075f513,
            "ori a0,a1,7":0x0075e513,"xori a0,a1,7":0x0075c513,
            "slti a0,a1,-1":0xfff5a513,"sltiu a0,a1,1":0x0015b513,
            "slli a0,a1,31":0x01f59513,"srli a0,a1,31":0x01f5d513,"srai a0,a1,31":0x41f5d513,
            "lb a0,4(sp)":0x00410503,"lbu a0,4(sp)":0x00414503,
            "lh a0,4(sp)":0x00411503,"lhu a0,4(sp)":0x00415503,"lw a0,4(sp)":0x00412503,
            "sb a0,4(sp)":0x00a10223,"sh a0,4(sp)":0x00a11223,"sw a0,4(sp)":0x00a12223,
            "beq zero,zero,8":0x00000463,"bne zero,zero,8":0x00001463,
            "blt zero,zero,8":0x00004463,"bge zero,zero,8":0x00005463,
            "bltu zero,zero,8":0x00006463,"bgeu zero,zero,8":0x00007463,
            "jal ra,8":0x008000ef,"jalr zero,0(ra)":0x00008067,
            "lui t0,0x40000":0x400002b7,"auipc a0,0x12345":0x12345517,
            "nop":0x00000013,"mv a0,a1":0x00058513}
        for source,word in pairs.items():
            with self.subTest(source=source): self.assertEqual(assemble(source),[word])
    def test_li_and_labels(self):
        self.assertEqual(assemble("li a0,0x12345fff"),[0x12346537,0xfff50513])
        self.assertEqual(assemble("li a0,-2147483648"),[0x80000537,0x00050513])
        self.assertEqual(assemble("jal ra,end\nli a0,4096\nend: nop"),[0x00c000ef,0x00001537,0x00050513,0x13])
        self.assertEqual(assemble("loop: nop\nbeq zero,zero,loop"),[0x13,0xfe000ee3])
    def test_rejections(self):
        for source in ("add x32,x0,x1","addi x1,x0,2048","lw a0,-2049(sp)","slli a0,a0,32",
                       "beq x0,x0,2","jal ra,6","beq x0,x0,4096","jal ra,1048576",
                       "li x1,4294967296","li x1,-2147483649","lui x1,1048576",
                       "x: nop\nx: nop","jal ra,missing","sw a0,4sp","add a0,a1","nop a0"):
            with self.subTest(source=source),self.assertRaises(ValueError): assemble(source)
    def test_runner_fail_closed(self):
        from run_validation import validate
        for text,rc in (("PASS\nFatal: mismatch",0),("PASS\n",1),("",0),("CPU_TEST_FAILED\nPASS",0)):
            with self.assertRaises(RuntimeError): validate(text,rc,["PASS"])
        validate("PASS\n",0,["PASS"])
if __name__=="__main__": unittest.main()
