# 改动说明

## 顶层接口变更
- 将 `top.v` 的顶层接口从类 SRAM 接口改为标准 AXI 通道接口（`ar/aw/w/r/b`）。
- 顶层模块名确定为 `mycpu_top`。
- 顶层端口调整为：
  - 时钟与复位：`aclk`, `aresetn`
  - 中断输入：`ext_int[5:0]`（原为 `int`，为对齐 `soc_axi_lite_top.v` 而修改）
- 移除所有对外 SRAM 引脚，仅保留 AXI 总线接口。

## 桥接逻辑新增
- 在 `top.v` 内部新增 SRAM → AXI 桥接信号。
- 实例化 `cpu_axi_interface` 模块，用于连接 CPU 类 SRAM 侧与 AXI 总线侧。
- CPU 侧仍保持类 SRAM 访问方式：
  - 指令访问固定为 word（4 字节）读；
  - 数据访问 size 由 `data_ram_wea` 和操作类型推导。

## AXI 事务配置
- 所有 AXI 事务为单次传输（`LEN = 0`），不启用 burst。
- `ARBURST` / `AWBURST` 固定为 `INCR`。
- `ARSIZE` / `AWSIZE` 由 `{1'b0, size}` 生成，支持 1/2/4 字节访问。
- `ARLEN` / `AWLEN` 宽度设为 4 位，与测试工程对齐。

## 流水线控制增强
- 引入 `inst_data_ok` / `data_data_ok` 信号参与流水线暂停控制。
- 指令侧：当 `inst_data_ok = 0` 时，暂停 F/D 阶段。
- 数据侧（Load/Store）：若未返回，则暂停 F/D/E/W 阶段，防止写回错位。
- 新增 `stallW` 信号：
  - 控制器 W 阶段寄存器使用 `flopenrc + stallW` 使能；
  - 数据通路 W 阶段寄存器统一受 `stallW` 控制，确保同步冻结。

## 写回调试信号修正
- `debug_wb_rf_wen` 增加门控逻辑：
  - 仅当 `pcW` 发生变化 **且** `validW = 1` 时才有效；
  - 避免同一条指令在 `pcW` 不变时重复提交写回，解决 trace 对比中 “PC 落后 4” 问题。