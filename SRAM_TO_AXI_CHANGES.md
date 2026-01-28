# MIPS CPU SRAM 到 AXI 接口改动文档

本文档记录了将 MIPS CPU 从 SRAM 接口改造为 AXI 接口所做的所有修改。

## 1. 概述

### 1.1 改动目的
将原有的同步 SRAM 接口 CPU 改造为支持 AXI4 总线协议的版本，以便与 AXI 互联架构的 SoC 集成。

### 1.2 主要改动
- 新增 AXI 接口转换模块
- 修改顶层模块接口
- 添加流水线暂停（stall）机制以处理 AXI 访问延迟
- 修改异常/中断处理逻辑以适应 AXI 时序

---

## 2. 新增文件

### 2.1 `cpu_axi_interface.v`
**功能**：SRAM-like 接口到 AXI4 协议转换桥

**主要特性**：
- 支持指令和数据两个通道的请求仲裁
- 实现 AXI4 的 5 个通道（AR、R、AW、W、B）握手协议
- 数据通道优先级高于指令通道

**接口说明**：
```verilog
// SRAM-like 接口（CPU 侧）
input  inst_req, inst_wr, inst_size, inst_addr, inst_wdata
output inst_rdata, inst_addr_ok, inst_data_ok

input  data_req, data_wr, data_size, data_addr, data_wdata
output data_rdata, data_addr_ok, data_data_ok

// AXI4 接口（总线侧）
output arid, araddr, arlen, arsize, arburst, arvalid...
input  arready, rid, rdata, rresp, rlast, rvalid...
// ... 其他 AXI 信号
```

### 2.2 `i_sram_to_sram_like.v`
**功能**：指令 SRAM 接口到 SRAM-like 接口转换

**主要特性**：
- 管理指令读取的握手流程（addr_rcv, do_finish 状态机）
- 生成 `i_stall` 信号，在指令未返回时暂停流水线
- **地址验证**：检查 AXI 返回数据是否对应当前请求地址，防止异常跳转时使用旧数据

**关键逻辑**：
```verilog
// 保存请求地址，用于验证返回数据
reg [31:0] req_addr_save;
wire addr_match = (req_addr_save == inst_sram_addr);
wire valid_data_ok = inst_data_ok & addr_match;

// 只有地址匹配时才接受数据
always @(posedge clk) begin
    inst_rdata_save <= valid_data_ok ? inst_rdata : inst_rdata_save;
end
```

### 2.3 `d_sram_to_sram_like.v`
**功能**：数据 SRAM 接口到 SRAM-like 接口转换

**主要特性**：
- 支持读写操作
- 管理数据访问的握手流程
- 生成 `d_stall` 信号

---

## 3. 修改的文件

### 3.1 `top.v` - 顶层模块

**接口变更**：
```verilog
// 原 SRAM 接口
output inst_sram_en, inst_sram_wen, inst_sram_addr, inst_sram_wdata
input  inst_sram_rdata
// ...

// 新 AXI 接口
output [3:0]  arid, awid, wid
output [31:0] araddr, awaddr, wdata
output        arvalid, awvalid, wvalid, rready, bready
input         arready, awready, wready, rvalid, bvalid
// ... 完整 AXI4 信号
```

**内部结构变更**：
- 实例化 `i_sram_to_sram_like` 和 `d_sram_to_sram_like` 模块
- 实例化 `cpu_axi_interface` 模块
- 连接 `mips` 核心的 SRAM 接口到转换模块

### 3.2 `mips.v` - CPU 核心顶层

**新增端口**：
```verilog
input wire i_stall,      // 指令访问暂停
input wire d_stall,      // 数据访问暂停
output wire longest_stall // 最长暂停信号（用于 SRAM-like 模块）
```

**取指使能逻辑**：
```verilog
// 异常或 PC 未对齐时禁止取指
assign inst_sram_en = ~flush_exception & ~pc_misaligned;
```

### 3.3 `hazard.v` - 冒险检测单元

**新增端口**：
```verilog
input wire i_stall,       // AXI 指令暂停
input wire d_stall,       // AXI 数据暂停
input wire stall_divE,    // 除法器暂停
output wire longest_stall, // 最长暂停（供 SRAM-like 模块使用）
output wire flushF         // F 阶段清空（异常时）
```

**暂停逻辑**：
```verilog
// AXI 相关暂停
wire longest_stall = i_stall | d_stall | stall_divE;

// 各阶段暂停信号
assign stallD = lwstall | branch_stall | jump_stall | link_stall | longest_stall;
assign stallF = stallD & ~flush_exception_safe;
assign stallE = longest_stall;
assign stallM = longest_stall;
assign stallW = longest_stall & ~flush_exception_safe;

// 异常清空信号
assign flushF = flush_exception_safe;
assign flushD = flush_exception_safe;
```

### 3.4 `datapath.v` - 数据通路

**新增端口**：
```verilog
input wire i_stall, d_stall,
output wire longest_stall
```

**主要修改**：

#### 3.4.1 AXI 暂停信号传递
```verilog
// 将 AXI 暂停信号传递给 hazard 单元
hazard hazard(
    .i_stall(i_stall),
    .d_stall(d_stall),
    .stall_divE(stall_divE),
    .longest_stall(longest_stall),
    // ...
);
```

#### 3.4.2 CP0 寄存器延迟（中断检测）
```verilog
// W 阶段的 CP0 寄存器值（用于中断检测）
// 延迟一级确保软件中断在正确的指令上触发
wire [31:0] cp0_status_W, cp0_cause_W, cp0_epc_W;
flopenrc #(32) r_cp0_statusW(.clk(clk),.rst(rst),.en(~stallW),.clear(flushW),
                             .d(cp0_status_o),.q(cp0_status_W));
flopenrc #(32) r_cp0_causeW(.clk(clk),.rst(rst),.en(~stallW),.clear(flushW),
                            .d(cp0_cause_o),.q(cp0_cause_W));
flopenrc #(32) r_cp0_epcW(.clk(clk),.rst(rst),.en(~stallW),.clear(flushW),
                          .d(cp0_epc_o),.q(cp0_epc_W));

// 中断检测使用 W 阶段的 CP0 值
exception u_exception(
    .cp0_status(cp0_status_W),
    .cp0_cause(cp0_cause_W),
    .cp0_epc(cp0_epc_W),
    // ...
);
```

**说明**：软件中断通过 `mtc0` 写入 Cause 寄存器触发。如果使用当前周期的 CP0 值，中断会在 `mtc0` 指令本身触发，导致 EPC 保存错误地址。延迟一级后，中断在下一条指令触发，EPC 正确保存。

#### 3.4.3 W 阶段写回使能控制
```verilog
// 暂停时禁止写回，避免重复写入
wire regwrite_for_debug = regwriteW & ~stallW;
assign debug_wb_rf_wen = {4{regwrite_for_debug}};
```

### 3.5 `pc.v` - 程序计数器

**新增端口**：
```verilog
input wire flush,        // 异常清空
input wire [31:0] newpc  // 异常入口地址
```

**优先级逻辑**：
```verilog
always @(posedge clk) begin
    if (rst)
        q <= 32'hbfc00000;
    else if (flush)
        q <= newpc;        // 异常跳转优先级最高
    else if (en)
        q <= din;
    // else 保持
end
```

### 3.6 `flopenrc.v` - 带清零的流水线寄存器

**优先级调整**：
```verilog
always @(posedge clk) begin
    if (rst)
        q <= 0;
    else if (clear)      // clear 优先级高于 en
        q <= 0;          // 确保异常 flush 时即使有 stall 也能清零
    else if (en)
        q <= d;
end
```

---

## 4. 关键设计要点

### 4.1 AXI 访问延迟处理
- 每次 AXI 访问可能需要多个周期完成
- `i_stall` 和 `d_stall` 信号暂停整个流水线
- `longest_stall` 用于 SRAM-like 模块判断何时清除 `do_finish` 状态

### 4.2 异常跳转时的指令丢弃
- 异常发生时，正在进行的 AXI 读事务可能返回旧地址的数据
- `i_sram_to_sram_like` 模块通过地址验证丢弃无效数据
- 自动重新发起对新 PC 地址的读请求

### 4.3 中断时序
- 软件中断通过 `mtc0` 设置 Cause 寄存器触发
- CP0 寄存器值延迟一个流水级用于中断检测
- 确保 EPC 保存正确的返回地址

### 4.4 流水线控制信号优先级
```
rst > flush/clear > stall > normal
```

---

## 5. 测试结果

通过全部 89 个功能测试点，包括：
- 基本算术/逻辑指令（测试点 1-47）
- 访存指令（测试点 48-64）
- 异常处理（测试点 65-89）
  - syscall, break 异常
  - 地址错误异常（AdEL, AdES）
  - 保留指令异常
  - 溢出异常
  - 软件中断

---

## 6. 文件清单

| 文件名 | 状态 | 说明 |
|--------|------|------|
| `top.v` | 修改 | 顶层接口改为 AXI |
| `mips.v` | 修改 | 添加暂停信号 |
| `datapath.v` | 修改 | 添加暂停逻辑和 CP0 延迟 |
| `hazard.v` | 修改 | 添加 AXI 暂停处理 |
| `pc.v` | 修改 | 添加异常跳转支持 |
| `flopenrc.v` | 修改 | 调整清零优先级 |
| `cpu_axi_interface.v` | 新增 | AXI 协议转换 |
| `i_sram_to_sram_like.v` | 新增 | 指令接口转换 |
| `d_sram_to_sram_like.v` | 新增 | 数据接口转换 |
