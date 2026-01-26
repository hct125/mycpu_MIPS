# mycpu_MIPS 改动说明

## 测试结果
✅ 通过全部 89 个功能测试点，支持 57 条指令

## 新增文件

| 文件 | 说明 |
|------|------|
| `src/cp0_reg.v` | CP0 协处理器 |
| `src/exception.v` | 异常检测模块 |
| `src/mmu.v` | 地址转换模块 |

**注意**：需要手动添加到 Vivado 项目的 Design Sources 中。

---

## 修改文件汇总

| 文件 | 改动说明 |
|------|---------|
| `top.v` | 改为 SoC SRAM 接口，CPU 用反相时钟 `~clk` |
| `include/defines2.vh` | 添加 CP0 和异常类型宏定义 |
| `src/mips.v` | 添加调试信号和异常控制信号端口 |
| `src/controller.v` | 添加 CP0/异常控制信号流水线传递 |
| `src/main_dec.v` | 添加特权指令译码，添加 `ri` 输出 |
| `src/datapath.v` | 实例化 CP0/exception，添加调试信号输出，修复 BLTZAL |
| `src/hazard.v` | 添加 `flush_exception` 处理 |
| `src/hilo_reg.v` | 添加 `flushE` 阻止异常时写 HI/LO |
| `src/mem_write_ctrl.v` | 添加 `flush_exception` 阻止异常时写内存 |
| `src/div.v` | 保存操作数符号位，修复商符号错误 |
| `src/pc.v` | 复位地址改为 `0xbfc00000` |
| `utils/instdec.v` | 添加 MFC0, MTC0, ERET 显示 |

---

## 关键修复

1. **PC 偏移问题**：CPU 使用反相时钟 `~clk`，配合同步 Block RAM

2. **DIV 商符号错误**：除法开始时保存操作数符号位

3. **memtoregW 缺失**：W 阶段使用流水线传递的 `memtoregW`

4. **SB/SH 数据未对齐**：写数据复制到所有位置

5. **BLTZAL 不写 $31**：修改 `wa3` 逻辑，link 指令始终写

6. **异常时 HI/LO 被写**：添加 `flushE` 门控

7. **ADES 异常时内存被写**：添加 `flush_exception` 门控

8. **RI 异常未触发**：`main_dec.v` 添加 `ri` 信号

---

## 支持的指令（57 条）

**算术**：ADD, ADDU, ADDI, ADDIU, SUB, SUBU, SLT, SLTU, SLTI, SLTIU, MULT, MULTU, DIV, DIVU

**逻辑**：AND, ANDI, OR, ORI, XOR, XORI, NOR, LUI

**移位**：SLL, SLLV, SRL, SRLV, SRA, SRAV

**分支跳转**：BEQ, BNE, BGEZ, BGTZ, BLEZ, BLTZ, BGEZAL, BLTZAL, J, JAL, JR, JALR

**访存**：LW, LH, LHU, LB, LBU, SW, SH, SB

**数据移动**：MFHI, MFLO, MTHI, MTLO

**特权**：MFC0, MTC0, ERET, SYSCALL, BREAK
