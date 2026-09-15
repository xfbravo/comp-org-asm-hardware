"""Small strict RV32I assembler. No GNU tools required; addresses follow li expansion."""
from pathlib import Path
import re
import sys

NAMES = "zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6".split()
REG = {n:i for i,n in enumerate(NAMES)}
REG["fp"]=8
R = {"add":(0,0),"sub":(0,32),"sll":(1,0),"slt":(2,0),"sltu":(3,0),"xor":(4,0),"srl":(5,0),"sra":(5,32),"or":(6,0),"and":(7,0)}
I = {"addi":0,"slti":2,"sltiu":3,"xori":4,"ori":6,"andi":7}
L = {"lb":0,"lh":1,"lw":2,"lbu":4,"lhu":5}
S = {"sb":0,"sh":1,"sw":2}
B = {"beq":0,"bne":1,"blt":4,"bge":5,"bltu":6,"bgeu":7}
def reg(s):
    if s in REG: return REG[s]
    if re.fullmatch(r"x(?:[0-9]|[12][0-9]|3[01])",s): return int(s[1:])
    raise ValueError("invalid register: "+s)
def number(s):
    return int(s,16) if "0x" in s.lower() else int(s,10)
def signed(v,bits):
    if not -(1<<(bits-1)) <= v < (1<<(bits-1)):
        raise ValueError(f"immediate {v} outside signed {bits} bits")
    return v & ((1<<bits)-1)
def ir(rd,rs,imm,f3,opcode=0x13):
    return signed(imm,12)<<20 | reg(rs)<<15 | f3<<12 | reg(rd)<<7 | opcode
def memory(s):
    m=re.fullmatch(r"([^()]+)\(([^()]+)\)",s.replace(" ",""))
    if not m: raise ValueError("expected offset(register): "+s)
    return number(m[1]),m[2]
def expand(op,args):
    if op=="nop":
        if args: raise ValueError("nop takes no operands")
        return [("addi",["zero","zero","0"])]
    if op=="mv":
        if len(args)!=2: raise ValueError("mv requires two operands")
        return [("addi",[args[0],args[1],"0"])]
    if op=="li":
        if len(args)!=2: raise ValueError("li requires two operands")
        v=number(args[1]); reg(args[0])
        if not -(1<<31)<=v<=0xffffffff: raise ValueError("li outside 32 bits")
        if v>=1<<31: v-=1<<32
        if -2048<=v<=2047: return [("addi",[args[0],"zero",str(v)])]
        hi=(v+2048)>>12; lo=v-(hi<<12)
        return [("lui",[args[0],str(hi & 0xfffff)]),("addi",[args[0],args[0],str(lo)])]
    return [(op,args)]
def assemble(source):
    labels={}; rows=[]
    for lineno,raw in enumerate(source.splitlines(),1):
        line=raw.split("#",1)[0].strip()
        while ":" in line:
            label,line=line.split(":",1); label=label.strip(); line=line.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*",label): raise ValueError("invalid label")
            if label in labels: raise ValueError("duplicate label: "+label)
            labels[label]=4*len(rows)
        if not line: continue
        fields=line.split(None,1); op=fields[0].lower()
        args=[a.strip() for a in fields[1].split(",")] if len(fields)==2 else []
        for opcode,operands in expand(op,args): rows.append((lineno,opcode,operands))
    words=[]
    for idx,(lineno,op,a) in enumerate(rows):
        pc=4*idx
        def target(s,bits):
            if s in labels: v=labels[s]-pc
            else:
                try: v=number(s)
                except ValueError: raise ValueError("undefined label: "+s)
            signed(v,bits)
            if v%4: raise ValueError("RV32I target must be 4-byte aligned")
            return v
        try:
            count=0 if op=="ecall" else 2 if op in (*L,*S,"lui","auipc","jal","jalr") else 3
            if len(a)!=count: raise ValueError("wrong operand count")
            if op in R:
                f3,f7=R[op]; w=f7<<25|reg(a[2])<<20|reg(a[1])<<15|f3<<12|reg(a[0])<<7|0x33
            elif op in I: w=ir(a[0],a[1],number(a[2]),I[op])
            elif op in ("slli","srli","srai"):
                sh=number(a[2])
                if not 0<=sh<32: raise ValueError("shift outside 0..31")
                w=ir(a[0],a[1],sh+(1024 if op=="srai" else 0),1 if op=="slli" else 5)
            elif op in L:
                imm,base=memory(a[1]); w=ir(a[0],base,imm,L[op],3)
            elif op in S:
                imm,base=memory(a[1]); imm=signed(imm,12)
                w=(imm>>5)<<25|reg(a[0])<<20|reg(base)<<15|S[op]<<12|(imm&31)<<7|0x23
            elif op in B:
                imm=target(a[2],13)
                w=((imm>>12)&1)<<31|((imm>>5)&63)<<25|reg(a[1])<<20|reg(a[0])<<15|B[op]<<12|((imm>>1)&15)<<8|((imm>>11)&1)<<7|0x63
            elif op=="jal":
                imm=target(a[1],21)
                w=((imm>>20)&1)<<31|((imm>>1)&1023)<<21|((imm>>11)&1)<<20|((imm>>12)&255)<<12|reg(a[0])<<7|0x6f
            elif op=="jalr":
                imm,base=memory(a[1]); w=ir(a[0],base,imm,0,0x67)
            elif op in ("lui","auipc"):
                imm=number(a[1])
                if not -(1<<19)<=imm<(1<<20): raise ValueError("upper immediate outside 20 bits")
                w=(imm&0xfffff)<<12|reg(a[0])<<7|(0x37 if op=="lui" else 0x17)
            elif op=="ecall": w=0x73
            else: raise ValueError("unsupported opcode: "+op)
        except (ValueError,KeyError) as exc: raise ValueError(f"line {lineno}: {op} {a}: {exc}") from exc
        words.append(w&0xffffffff)
    return words
def mem_text(source):
    words=assemble(source)
    if len(words)>1024: raise ValueError("program exceeds 1024-word instruction ROM")
    return "".join(f"{w:08x}\n" for w in words)
def encode(src,out):
    Path(out).write_text(mem_text(Path(src).read_text(encoding="utf-8")),encoding="ascii")
if __name__=="__main__":
    encode(sys.argv[1],sys.argv[2])
