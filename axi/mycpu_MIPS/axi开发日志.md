# 开发日志

## 第一阶段：接口适配
- 将 `mycpu_top` 的顶层接口与 `soc_axi_lite_top.v` 对齐。
- 调整 AXI 信号位宽（如 `ARLEN/AWLEN = 4'b0`），避免与 crossbar 端口不匹配。
- 修改中断端口名为 `ext_int[5:0]`，以匹配 SoC 实例化需求。

## 第二阶段：桥接规范化
- 完成 `cpu_axi_interface` 模块集成。
- 设定 AXI 事务为单次、INCR 模式，`LEN=0`。
- 将 CPU 侧 `data_size`（来自 `opM` 译码，如 LB/LH/LW/SB/SH/SW）绑定到 AXI 的 `SIZE` 字段。

## 第三阶段：握手与暂停机制
- 引入 `inst_data_ok` 和 `data_data_ok` 参与 hazard 控制逻辑。
- 在取指或数据未就绪时，触发 `stallF` 或全流水线暂停。
- W 阶段增加 `stallW`，确保控制信号与数据通路在随机延迟下仍能同步写回。

## 第四阶段：仿真与调试对齐
- 使用 `soc_axi_func/testbench/mycpu_tb.v` 作为功能测试入口。
- 修复 trace 输出中因写回重复导致的 PC 错位问题（参考 PC=0xbfc00004 vs DUT PC=0xbfc00000）。
- 最终通过 `pcW_prev` 比较 + `validW` 门控，确保每条指令仅提交一次写回。

## 后续待办
- 评估 AXI 等待周期下的完整握手支持（当前 CPU 侧尚未引入 `addr_ok`/`data_ok` 等精细控制）。
- 优化总线仲裁策略，避免数据请求长期阻塞取指请求。