# 计算机组成与汇编小学期硬件实验

本仓库用于保存计算机组成原理与汇编原理小学期硬件实验相关内容。

当前已经整理出的计算机组成部分代码位于：

```text
computer_organization_cpu/
```

该目录中包含一个可直接打开的 Vivado 2022.1 工程：

```text
computer_organization_cpu/computer_organization_cpu.xpr
```

## 目录说明

- `computer_organization_cpu/computer_organization_cpu.xpr`：Vivado 工程文件，可以直接双击打开。
- `computer_organization_cpu/src/`：重构后的处理器 Verilog 源码。
- `computer_organization_cpu/sim/`：自检仿真平台和指令存储器初始化文件。
- `computer_organization_cpu/docs/implementation.md`：计算机组成部分的实现原理说明。
- `computer_organization_cpu/docs/board_preparation.md`：下板准备、系统级仿真和 MMIO 地址规划。
- `computer_organization_cpu/constraints/board_template.xdc`：待填充的板级约束模板。
- `computer_organization_cpu_vivado2019_2_backup/`：保留 Vivado 2019.2 工程壳的同步备份。
- `小学期/`：往年参考资料和旧工程，默认不提交到仓库。

## 仿真验证

使用 Vivado 打开：

```text
D:/comp-org-asm-hardware/computer_organization_cpu/computer_organization_cpu.xpr
```

然后在左侧流程导航中依次选择“仿真”“运行仿真”“运行行为仿真”。

如果仿真没有自动跑完，在命令控制台中输入：

```tcl
run all
```

当前自检程序通过时，控制台会输出：

```text
CPU TEST PASSED in 37 cycles
```

其中 `tb_cpu` 是仿真顶层，`cpu_core` 是设计顶层。

仿真还会输出总周期数、提交指令数、CPI 和 IPC，供实验报告中的性能测试方案使用。

## 下板准备

当前工程已经加入板级无关的 `board_top` 顶层和七段数码管显示模块。由于开发板型号尚未确定，仓库暂不包含具体 `.xdc` 引脚约束；拿到开发板型号后，需要补充时钟、复位、LED、数码管和其他外设的引脚映射。

当前 Vivado 工程默认设计顶层仍为 `cpu_core`。真正下板前，需要将 Design Sources 顶层切换为 `board_top`。

系统级仿真入口为 `tb_board_top`。在 Vivado 的 Simulation Sources 中将顶层切换为 `tb_board_top` 后运行行为仿真，通过时会输出：

```text
BOARD TOP TEST PASSED
```
