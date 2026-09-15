"""Vivado 2019.2-only reproducible validation; a failure never emits aggregate PASS."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
TESTS = {
    "tb_uart_controller": ["UART_TX_PASS", "UART_RX_PASS", "UART_FIFO_PASS"],
    "tb_uart_mmio": ["UART_MMIO_PASS"],
    "tb_data_mem": ["DATA_MEM_TEST_PASSED"],
    "tb_seven_seg_scan": ["SEVEN_SEG_2026_TEST_PASSED"],
    "tb_cpu_uart": ["CPU_UART_TEST_PASSED"],
    "tb_cpu_uart_echo": ["CPU_UART_ECHO_TEST_PASSED"],
    "tb_cpu_mmio_hazards": ["CPU_MMIO_HAZARDS_PASS"],
    "tb_cpu_uart_command": ["CPU_COMMAND_HELP_PASS", "CPU_COMMAND_ADD_PASS", "CPU_COMMAND_SORT_PASS", "CPU_COMMAND_BOUNDARY_PASS"],
    "tb_board_top": ["BOARD_TOP_TEST_PASSED"],
    "tb_board_uart_command": ["BOARD_COMMAND_PASS"],
}
def hashes():
    files = []
    for directory in ("rtl", "asm", "mem", "constr", "tools", "sim", "vivado", "ip"):
        files += [f for f in (ROOT/directory).rglob("*") if f.is_file()
                  and f.suffix in (".v", ".vh", ".S", ".mem", ".xdc", ".py", ".ps1", ".tcl", ".xml")
                  and not any(s in f.parts for s in ("work", "packager_work", "__pycache__"))
                  and not any(s.startswith("asm_uart_2019_2.") for s in f.relative_to(ROOT).parts)]
    return {f.relative_to(ROOT).as_posix(): hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files)}
def validate(text, returncode, markers):
    if returncode != 0:
        raise RuntimeError(f"process exit {returncode}")
    if re.search(r"(?im)^\s*(?:FATAL:|ERROR:|Fatal:)|\b[A-Z0-9_]+_(?:FAIL|FAILED)\b", text):
        raise RuntimeError("error/fatal/failure in tool output")
    for marker in markers:
        if not re.search(r"(?m)^"+re.escape(marker)+r"\s*$", text):
            raise RuntimeError("missing completion marker: "+marker)
def run(vivado, script, name, markers, args=(), timeout=300):
    logfile = BUILD/(name+".log")
    command = [vivado, "-mode", "batch", "-nojournal", "-log", str(logfile),
               "-source", str(ROOT/"vivado"/script), "-tclargs", *args]
    started = time.time()
    console = BUILD/(name+".console.log")
    with console.open("w") as out:
        proc = subprocess.Popen(command, cwd=BUILD, stdout=out, stderr=subprocess.STDOUT)
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
            raise RuntimeError(f"{name}: process timeout {timeout}s")
    text = logfile.read_text(errors="replace") if logfile.exists() else console.read_text(errors="replace")
    validate(text, code, markers)
    console.unlink(missing_ok=True)
    print("VERIFIED", name, flush=True)
    return {"status": "PASS", "seconds": round(time.time()-started, 2), "markers": markers}
def simulate(vivado, top, markers):
    """Run the 2019.2 compiler/simulator in an isolated directory for each test."""
    work=BUILD/"_sim"/top
    if work.exists():
        if not work.resolve().is_relative_to((BUILD/"_sim").resolve()): raise RuntimeError("unsafe simulation path")
        shutil.rmtree(work)
    work.mkdir(parents=True)
    for f in (ROOT/"mem").glob("*.mem"): shutil.copy2(f,work/f.name)
    (work/"run.tcl").write_text("run all\nquit\n")
    bindir=Path(vivado).parent
    rtl=[str(f) for f in sorted((ROOT/"rtl").glob("*.v"))]
    commands=[
        [str(bindir/"xvlog.bat"),"-i",str(ROOT/"rtl"),"-work","xil_defaultlib",*rtl,str(ROOT/"sim"/(top+".v"))],
        [str(bindir/"xelab.bat"),"--debug","typical","--snapshot",top,"xil_defaultlib."+top],
        [str(bindir/"xsim.bat"),top,"-tclbatch","run.tcl","-log","simulation.log"]]
    started=time.time()
    combined=""
    for index,command in enumerate(commands):
        console=work/f"step{index}.log"
        with console.open("w") as out:
            proc=subprocess.Popen(command,cwd=work,stdout=out,stderr=subprocess.STDOUT)
            try: code=proc.wait(timeout=300)
            except subprocess.TimeoutExpired:
                subprocess.run(["taskkill","/PID",str(proc.pid),"/T","/F"],capture_output=True)
                raise RuntimeError(top+": simulation process timeout")
        text=console.read_text(errors="replace")
        combined+=text+"\n"
        (BUILD/(top+".log")).write_text(combined,encoding="utf-8")
        validate(text,code,markers if index==2 else [])
    print("VERIFIED",top,flush=True)
    return {"status":"PASS","seconds":round(time.time()-started,2),"markers":markers,"engine":"Vivado 2019.2 xvlog/xelab/xsim"}

def discover(explicit):
    candidates = [explicit, os.environ.get("XILINX_VIVADO","")+"/bin/vivado.bat",
                  r"D:\Xilinx_2019\Vivado\2019.2\bin\vivado.bat",
                  r"C:\Xilinx\Vivado\2019.2\bin\vivado.bat",
                  r"D:\Xilinx\Vivado\2019.2\bin\vivado.bat"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file(): return candidate
    raise RuntimeError("Vivado 2019.2 not found; specify --vivado")
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--vivado",default="")
    ap.add_argument("--mode",choices=["uart","regression","ip","build","all"],default="all")
    opts=ap.parse_args()
    BUILD.mkdir(exist_ok=True)
    report={"scope":opts.mode,"started_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
            "board_test":"NOT_PERFORMED","tests":{},"status":"FAIL"}
    path=BUILD/("verification_"+opts.mode+".json")
    try:
        vivado=discover(opts.vivado)
        report["vivado_executable"]=vivado
        report["tests"]["tool_version"]=run(vivado,"check_version.tcl","tool_version",["VIVADO_2019_2_PASS"])
        report["tool_version"]=(BUILD/"tool_version.txt").read_text().strip()
        if opts.mode in ("all","regression","uart"):
            if opts.mode!="uart":
                subprocess.run([sys.executable,"-B",str(ROOT/"tools"/"verify_mem.py")],check=True)
            report["tests"]["create_project"]=run(vivado,"create_project.tcl","create_project",["PROJECT_CREATE_PASS"])
            tests={"tb_uart_controller":TESTS["tb_uart_controller"]} if opts.mode=="uart" else TESTS
            for top,markers in tests.items():
                report["tests"][top]=simulate(vivado,top,markers)
        if opts.mode in ("all","regression","ip"):
            report["tests"]["ip_package"]=run(vivado,"package_uart_ip.tcl","ip_package",["UART_IP_PACKAGE_PASS"])
            for f in ("uart_controller.v","uart_mmio_bridge.v"):
                if (ROOT/"rtl"/f).read_bytes()!=(ROOT/"ip"/"uart_mmio_bridge_1_0"/"hdl"/f).read_bytes():
                    raise RuntimeError("IP source differs: "+f)
            report["tests"]["ip_smoke"]=run(vivado,"run_ip_smoke.tcl","ip_smoke",["UART_IP_SMOKE_PASS"],timeout=600)
        if opts.mode in ("all","build"):
            if opts.mode=="build":
                subprocess.run([sys.executable,"-B",str(ROOT/"tools"/"verify_mem.py")],check=True)
                report["tests"]["create_project"]=run(vivado,"create_project.tcl","create_project",["PROJECT_CREATE_PASS"])
            before=hashes()
            report["tests"]["implementation"]=run(vivado,"build_bitstream.tcl","implementation",["FINAL_BUILD_PASS"],timeout=1800)
            if before!=hashes(): raise RuntimeError("Sources changed during implementation")
            report["bitstream_sha256"]=hashlib.sha256((BUILD/"asm_board_top.bit").read_bytes()).hexdigest()
            report["clocks"]={"board_hz":100000000,"cpu_uart_hz":50000000,"baud":115200}
        report["status"]="PASS"
        if opts.mode in ("all","regression"): print("ALL_REGRESSION_TESTS_PASSED")
    except Exception as exc:
        report["error"]=str(exc)
        raise
    finally:
        report["source_sha256"]=hashes()
        path.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        from clean_generated import cleanup
        cleanup()
if __name__=="__main__":
    main()
