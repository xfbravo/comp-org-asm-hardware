"""Small RV32I encoder for the instructions used by the UART demo.
Usage: python rv32_encoder.py hello_uart.S hello_uart.mem"""
import sys, re

REG = {"zero":0,"ra":1,"sp":2,"gp":3,"tp":4,"t0":5,"t1":6,"t2":7,"s0":8,"fp":8,"s1":9,"a0":10,"a1":11,"a2":12,"a3":13,"a4":14,"a5":15,"a6":16,"a7":17,"s2":18,"s3":19,"s4":20,"s5":21,"s6":22,"s7":23,"s8":24,"s9":25,"s10":26,"s11":27,"t3":28,"t4":29,"t5":30,"t6":31}
def reg(x): return int(x[1:]) if x.startswith('x') else REG[x]
def imm(x): return int(x,0)
def enc_r(f7,rs2,rs1,f3,rd,op=0x33): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_i(i,rs1,f3,rd,op): return ((i&0xfff)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(i,rs2,rs1,f3): return (((i>>5)&0x7f)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((i&0x1f)<<7)|0x23
def main(src,out):
    labels={}; rows=[]
    for line in open(src,encoding='utf-8'):
        line=line.split('#')[0].strip()
        if not line: continue
        if ':' in line:
            lab,line=line.split(':',1); labels[lab.strip()]=4*len(rows); line=line.strip()
        if line: rows.append(line)
    code=[]
    for pc,line in enumerate(rows):
        p=[x.strip() for x in re.split(r'[ ,\t]+',line) if x.strip()]
        op=p[0].lower()
        if op=='nop': w=0x13
        elif op=='lui': w=(imm(p[2])<<12)|(reg(p[1])<<7)|0x37
        elif op=='addi': w=enc_i(imm(p[3]),reg(p[2]),0,reg(p[1]),0x13)
        elif op=='andi': w=enc_i(imm(p[3]),reg(p[2]),7,reg(p[1]),0x13)
        elif op=='lw':
            m=re.match(r'(-?\w+)\((\w+)\)',p[2]); w=enc_i(imm(m.group(1)),reg(m.group(2)),2,reg(p[1]),3)
        elif op=='sw':
            m=re.match(r'(-?\w+)\((\w+)\)',p[2]); w=enc_s(imm(m.group(1)),reg(p[1]),reg(m.group(2)),2)
        elif op=='beq':
            off=labels[p[3]]-4*pc; w=((off>>12)&1)<<31|((off>>5)&0x3f)<<25|(reg(p[2])<<20)|(reg(p[1])<<15)|(((off>>1)&0xf)<<8)|(((off>>11)&1)<<7)|0x63
        elif op=='jal':
            off=labels[p[2]]-4*pc; w=((off>>20)&1)<<31|((off>>1)&0x3ff)<<21|((off>>11)&1)<<20|((off>>12)&0xff)<<12|(reg(p[1])<<7)|0x6f
        elif op=='jalr':
            m=re.match(r'(-?\w+)\((\w+)\)',p[2]); w=enc_i(imm(m.group(1)),reg(m.group(2)),0,reg(p[1]),0x67)
        elif op=='ecall': w=0x73
        else: raise ValueError(line)
        code.append(w & 0xffffffff)
    with open(out,'w',encoding='ascii') as f:
        f.write('\n'.join(f'{w:08x}' for w in code)+'\n')
if __name__=='__main__': main(sys.argv[1],sys.argv[2])
