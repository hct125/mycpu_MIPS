# D-Cache 错误修复记录（2026-01-29）

## 概要
本次修复分为两个相互关联但独立的问题：

- 问题 A：D-Cache 数据错位与脏读（导致 lw 读到 0x0ae2b41c）
- 问题 B：`nocache` 未连接/分流错误导致 kseg1 IO 访问被错误缓存（触发 Test Point 89）

下面按两部分分别记录问题定位、根因与修复要点。

---

## 问题 A — D-Cache 数据错位与脏读

### 现象
- 在 PC=0xbfc6356c 处的 `lw` 返回 `0x0ae2b41c`（参考值 `0x0a00b41c`），差异为第二字节被错误写为 `0xe2`。
- 仅在启用 D-Cache 时出现，无 cache 时通过参考测试。

### 根因（总结）
定位到三类制造脏数据/错字节的实现问题：

1) Refill 期间使用会变化的地址——`REFILL_WAIT` 直接使用 `cpu_index/tag/offset`，而这些信号会随流水线推进改变，导致重填写入错误的 cache line/字。
2) 命中路径为组合逻辑且未锁存——`cpu_rdata` 在命中时直接受 `cpu_addr/line_data` 驱动，流水线未停顿时地址变化会改变输出，M 阶段可能采到错误数据。
3) 写缓存时字节偏移计算错误——使用 `cpu_offset*8` 等直接位运算未正确区分“字内偏移”与“全局字节偏移”，跨字写入或部分字写入导致越界或错位。

### 修复要点

- 锁定重填地址：在进入 refill 时保存 `refill_index/refill_tag/refill_offset`，重填期间一律使用保存值完成写入与选择。

- 锁存命中数据：在命中时用寄存器锁存所需的 `word`（`selected_word`），使 `cpu_rdata` 在 M 阶段为稳定寄存器输出而非瞬时组合逻辑。

- 修正写偏移映射：按 `case (cpu_offset[3:2])` 选择字槽，再用 `cpu_wen` 控制字内字节写入；避免直接用 `cpu_offset*8` 导致位越界。

### 验证

- 在修复后，复现用例应由 `0x0ae2b41c` 变为 `0x0a00b41c`。
- 在仿真中确认 `refill_*` 在 refill 期间不变，且 `cpu_rdata_q` 在命中时持有正确的 `selected_word`。

---

## 问题 B — `nocache` 未连接导致 IO 访问被错误缓存（Test Point 89）

### 现象与复现

- 出现在 IO 设备功能测试（地址在 kseg1 非缓存区，如 0xbfafffec）
- 示例序列：`lui, sw, srl, lui, lw, bne, nop`。
- 期望：`sw` 将 0x56780000 写到 IO，IO 将数据右移 16 位，`lw` 返回 0x00005678。
- 实际：`sw` 后 D-Cache 缓存了 0x56780000（写入了 cpu_index 对应的 line），`lw` 命中并返回 0x56780000（绕过真实 IO 设备），导致 Test Point 89 失败。

示例错误输出：

- last : PC = 0xbfc00ccc, wb_rf_wnum = 0x08, wb_rf_wdata = 0x00005678
- reference: PC = 0xbfc00cd0, wb_rf_wnum = 0x09, wb_rf_wdata = 0x00005678
- mycpu : PC = 0xbfc00cd0, wb_rf_wnum = 0x09, wb_rf_wdata = 0x56780000

### 根因

- 在 `top.v` 中实例化 D-Cache 时未正确连接 `no_dcache`（或 `no_dcache` 在 MMU/顶层未传递到 cache），导致对 kseg1（非缓存区，IO 地址）的访问仍走 cache 路径并被缓存。
- 此外，分流/合流（bridge）若未与 `d_cache.v` 的接口对齐，可能在 bypass 路径上绕过必要的锁定/握手机制，放大问题。

### 修复要点

1) 顶层连接：在 `top.v` 中将 `no_dcache`（MMU 输出）正确传入 `d_cache`/`i_cache` 实例，或在顶层做分流：

   - `ram` 路（no_dcache=0）走 cache；
   - `conf` 路（no_dcache=1）绕过 cache，直接通过 `d_sram_to_sram_like` 等适配器到 AXI；

2) 使用桥接模块（已实现/推荐）：

   - `bridge_1x2`：根据 `no_dcache` 将 CPU 的 SRAM 请求分为 `ram`（cache）和 `conf`（bypass）两路；
   - `bridge_2x1`：合并 `ram` 和 `conf` 的 SRAM-like 输出到 AXI 桥。

3) 接口适配：保持 `d_cache.v` 和分流模块之间的接口一致（SRAM 接口 vs SRAM-like），或在桥接处加转换模块，避免直接绕过 cache 的锁定/握手逻辑。

### 验证

- 复现 IO 用例，确认 `lw` 读取到 IO 设备处理后的值 `0x00005678`，并且 Test Point 89 通过。
- 在仿真中观察：当 `no_dcache=1` 时访问应走 `conf` 路，确认 `cache` 的 `data_mem` 未被更新（无写入）；当 `no_dcache=0` 时按正常 cache 行为工作。

---

## 影响文件（摘要）

- `src/cache/d_cache.v`  — 修正写偏移、增加 `refill_*` 保存寄存器、增加 `cpu_rdata` 锁存逻辑
- `src/cache/i_cache.v`  — 对指令 cache 做同样的重填锁定与读锁存修正
- `src/top.v`          — 修正 `no_dcache` 传递与分流逻辑，添加/调整 `bridge_1x2` / `bridge_2x1` 的接线
- `src/sram/d_sram_to_sram_like.v` / `src/cpu_axi_interface.v` — 验证与分流后端握手一致性
