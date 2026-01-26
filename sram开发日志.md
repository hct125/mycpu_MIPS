# MIPS CPU 开发日志

## 2026-01-25 SoC SRAM 接口改造

### 概述
完成 CPU 从独立测试版本到 SoC SRAM 接口版本的改造。

### 主要改动

#### 1. 编译错误修复
- **问题**：`instr` 和 `mem_rdata` 被声明为 `reg` 但使用 `assign` 赋值
- **解决**：改为 `wire` 类型

#### 2. top.v 重构为 SoC 接口
```verilog
module top(
    input wire clk, resetn,
    input wire [5:0] ext_int,
    // 指令SRAM接口
    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr, inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,
    // 数据SRAM接口
    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr, data_sram_wdata,
    input wire [31:0] data_sram_rdata,
    // 调试信号
    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
```

#### 3. MMU 地址转换
- **kseg0/kseg1** (0x8000_0000 - 0xBFFF_FFFF)：物理地址 = {3'b0, 虚拟地址[28:0]}
- **其他**：直接映射

#### 4. Trace 调试信号
PC 值通过流水线传递 F→D→E→M→W，在 W 阶段输出调试信号。

#### 5. PC 复位地址
改为 `0xbfc00000`（MIPS 标准复位入口）

---

## 2026-01-25 SoC 功能测试调试

### 测试结果
✅ 通过测试点 1-62（52 条指令）

### Bug 修复记录

| Bug | 问题 | 解决方案 |
|-----|------|---------|
| **PC 偏移** | 首条指令 PC 为 0xbfc00004 | CPU 使用反相时钟 `~clk`，`inst_sram_en = 1'b1` |
| **DIV 商符号错误** | 除法 32 周期内输入信号变化 | 在除法开始时保存操作数符号位 |
| **Load 结果错误** | W 阶段使用了 D 阶段的 `memtoreg` | 添加 `memtoregW` 流水线传递 |
| **SB/SH 数据错位** | 写数据未对齐到正确位置 | SB 复制 4 次，SH 复制 2 次 |

---

## 2026-01-26 特权指令与异常处理

### 测试结果
✅ 通过全部 89 个测试点（57 条指令）

### 新增指令
MFC0, MTC0, ERET, SYSCALL, BREAK

### 新增异常
| 类型 | ExcCode | 说明 |
|------|---------|------|
| INT | 0x00 | 中断 |
| ADEL | 0x04 | 取指/Load 地址错误 |
| ADES | 0x05 | Store 地址错误 |
| SYS | 0x08 | 系统调用 |
| BP | 0x09 | 断点 |
| RI | 0x0A | 保留指令 |
| OV | 0x0C | 算术溢出 |

### 新增模块
- **cp0_reg.v**：实现 BadVAddr, Count, Compare, Status, Cause, EPC, PRId, Config
- **exception.v**：异常检测与优先级判断

### Bug 修复记录

| Bug | 问题 | 解决方案 |
|-----|------|---------|
| **BLTZAL/BGEZAL** | 分支不发生时未写 $31 | `wa3 = (branch & ~taken & ~link) ? 0 : wa3_raw` |
| **异常时 HI/LO 被更新** | flushE 时 hilo_reg 仍在写 | 添加 `flushE` 信号阻止写入 |
| **SW ADES 异常时内存被写** | 异常时 ben 未清零 | 添加 `flush_exception` 禁用写操作 |
| **RI 异常未触发** | riM 被硬编码为 0 | main_dec 添加 ri 输出，default 分支设为 1 |

### 异常处理流程
```
检测异常 → flush_exception = 1 → 清空流水线 + 禁用内存写 + 禁用 HI/LO 写
                              → CP0 更新 (Status, Cause, EPC)
                              → PC = 0xbfc00380
                              → ERET 返回 (PC = EPC)
```

### 延迟槽处理
- 异常在延迟槽：EPC = PC - 4，Cause.BD = 1
- 异常不在延迟槽：EPC = PC

---

## 修改文件清单

| 文件 | 类型 | 说明 |
|------|------|------|
| top.v | 重写 | SoC SRAM 接口 |
| mmu.v | 新增 | 地址转换 |
| cp0_reg.v | 新增 | CP0 协处理器 |
| exception.v | 新增 | 异常检测 |
| mips.v | 修改 | 调试信号端口 |
| datapath.v | 修改 | PC 传递、调试信号、异常处理 |
| controller.v | 修改 | 异常控制信号 |
| main_dec.v | 修改 | CP0/异常指令译码、ri 输出 |
| pc.v | 修改 | 复位地址 0xbfc00000 |
| div.v | 修改 | 保存操作数符号位 |
| hazard.v | 修改 | flush_exception |
| hilo_reg.v | 修改 | flushE 阻止写入 |
| mem_write_ctrl.v | 修改 | flush_exception 禁用写 |

---

## 指令列表（57 条）

- **算术**：ADD, ADDU, ADDI, ADDIU, SUB, SUBU, SLT, SLTU, SLTI, SLTIU, MULT, MULTU, DIV, DIVU
- **逻辑**：AND, ANDI, OR, ORI, XOR, XORI, NOR, LUI
- **移位**：SLL, SLLV, SRL, SRLV, SRA, SRAV
- **分支跳转**：BEQ, BNE, BGEZ, BGTZ, BLEZ, BLTZ, BGEZAL, BLTZAL, J, JAL, JR, JALR
- **访存**：LW, LH, LHU, LB, LBU, SW, SH, SB
- **数据移动**：MFHI, MFLO, MTHI, MTLO
- **特权**：MFC0, MTC0, ERET, SYSCALL, BREAK

---

## 经验总结

1. **时钟域**：Block RAM 同步读取需考虑相位，反相时钟是常用方案
2. **多周期操作**：必须在开始时保存所有输入，避免中途被修改
3. **流水线控制信号**：每个阶段使用该阶段的信号，不能跨阶段使用
4. **异常状态保护**：异常时阻止所有有副作用的操作
5. **MIPS 规范细节**：BLTZAL/BGEZAL 无论是否跳转都写 $31；延迟槽异常 EPC 要减 4

