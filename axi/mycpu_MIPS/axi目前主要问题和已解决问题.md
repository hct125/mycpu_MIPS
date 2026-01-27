# 当前遇到的问题

## 仿真卡死问题

- **现象**：仿真在 22000ns 以后一直卡住，debug_wb_pc 固定不前进。
- **原因分析**：
  - 数据请求长期抢占总线，导致 inst_data_ok 永远不回来。
  - RAM 端存在随机 mask（ram_random_mask）逻辑，会让 rvalid 被遮掉，出现长时间无返回的情况。
- **临时措施**：尝试修改 axi_wrap_ram.v 的 RUN_PERF_TEST 宏来关闭 mask，但未被接受。
- **结论**：AXI bridge 被 data_req 抢占（do_req_or=1），取指永远不被服务。RAM 侧 rvalid 被 mask 遮住，进一步放大了卡死问题。

## 仿真时间限制

- **现象**：控制台自动 run 1000ns，未出 PASS/ERROR。
- **解决**：手动在 Tcl Console 执行 run 10ms/run 100ms。


 **数据请求抢占问题**：
   - 数据请求长期占用总线资源，导致指令请求无法得到及时响应。
   - 尽管尝试调整了请求优先级，但仍未彻底解决问题。

 **RAM 返回值被遮罩问题**：
   - RAM 端的随机 mask 逻辑影响了 rvalid 的正常返回，导致长时间无响应情况的发生。


# 已解决
## 端口名不匹配

- **报错**：cannot find port 'ext_int'
- **解决**：修改 CPU 顶层端口名为 ext_int（仅改 CPU，未改测试环境）。

 **写回有效门控问题**（已解决 主要）：
   - 初始阶段由于写回有效信号没有与写回 PC 同步，导致 PC 落后 4 的功能对比失败。
   - 通过在 datapath.v 中增加写回判定门控解决了该问题。
现象

仿真在 2.4us 左右报错，参考模型显示写回 PC 为 0xbfc00004，而 myCPU 报 0xbfc00000，但写回寄存器号与数据一致。

关键定位

波形显示：pc 已经更新到 0xbfc00004，但 pcW 仍停在 0xbfc00000，同时 debug_wb_rf_wen 在同一条指令上持续有效，导致 testbench 连续读 trace，参考指针提前一行，形成 “PC 落后 4”。

根因

写回“有效信号”没有与写回 PC 同步：

- debug_wb_rf_wen 由 regwrite 直接驱动，

- 在流水线暂停或首条指令阶段，regwrite 可能保持为 1，

- 导致同一条写回在同一 pcW 上被重复提交。

解决措施（最终有效）

在 datapath.v 中增加写回判定门控：

- 记录 pcW_prev

- 仅当 pcW 发生变化且 validW 为真时才允许 debug_wb_rf_wen 输出

- 这样保证每条指令只提交一次，参考与 DUT 对齐

结果

修正后，不再出现 “PC 落后 4” 的首条写回误报，测试继续向后运行。