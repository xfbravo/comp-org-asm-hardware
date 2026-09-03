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
