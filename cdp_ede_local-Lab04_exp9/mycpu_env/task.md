根据当前工程里的实现，修改可归纳为下面几类（与 实践任务 9：前递 一致：在仍用 load-use 阻塞 的前提下，为寄存器读口增加 EX/MEM/WB 数据前递）。

1. mycpu_top.v
增加三根 32 位连线：es_to_ds_result、ms_to_ds_result、ws_to_ds_result（标注 //改动）。
id_stage 增加上述三路输入的例化连接。
exe_stage 增加 es_to_ds_result 输出连接；mem_stage 增加 ms_to_ds_result；wb_stage 增加 ws_to_ds_result。
2. exe_stage.v
增加输出端口 es_to_ds_result（alu_result），用于 ID 级前递。
增加对 es_to_ds_load_op 的显式赋值：es_valid & es_load_op，供 ID 做 load-use 判断（原先端口存在时可能未驱动，属 hazard 逻辑所需）。
es_to_ds_dest 仍为 dest & {5{es_valid}}（未再叠 gr_we 等与“仅前递/性能”无关的改法）。
端口处对被破坏的注释做了恢复（与“执行级目的寄存器”等表述一致）；前递相关新端口/新赋值处带 //改动。
3. mem_stage.v
增加输出端口 ms_to_ds_result，赋值为 ms_final_result（已含 load 读回或 ALU 结果），供 ID 前递。
注释在曾被弄乱处整理为可读中文；前递相关为 //改动。
4. wb_stage.v
增加输出端口 ws_to_ds_result，赋值为 ws_final_result（与写回寄存器堆的数据一致），供 ID 前递。
同样整理端口/assign 侧注释；前递相关 //改动。
5. id_stage.v（核心）
增加输入 es_to_ds_result / ms_to_ds_result / ws_to_ds_result。
读口 1（rj）：存在与 EX/MEM/WB 写口冲突可能时，按 EX → MEM → WB 优先级选前递数据，否则用 rf_rdata1。
读口 2（rk 或 rd，由 rf_raddr2 决定）：用 rkd_wait + 同一优先级前递，否则用 rf_rdata2。
Load-use：仅当 EX 为 load 且当前译码用到的源寄存器与 es_to_ds_dest 在 EX 上冲突时 load_stall；br_stall 在“分支类指令且 stall”时置位，配合 IF 侧已有 br_stall 语义。
br_taken：在 ~load_stall 下判定，避免在 load 阻塞时用错比较数。
ds_ready_go：改为 ds_valid & ~load_stall（不再用对一切 RAW 都等的 no_wait）。
ds_valid 冲刷：在 reset 清；在 br_taken && ds_ready_go 清（与参考前递流水一致）；不再用 reset | br_taken 一拍清 ID。
增加 assign load_op = inst_ld_w，保证送往 EX 的 load_op 与 res_from_mem 语义一致、不为 X。
6. 其它
检查数据前递：若 dest 未用 gr_we 屏蔽，store 等不写寄存器的指令仍会把 dest 当作前递目标，导致误前递。

应用两处修复：1. mem_stage 中非阻塞赋值（已改）；2. 前递目标寄存器应仅在指令真正写回 GPR 时有效（gr_we），否则 st.w 等仍带 rd 字段会误触发前递，导致读到错误数据甚至 X。

assign ms_to_ds_dest = ms_dest & {5{ms_valid}};//修改：寄存器号传递
assign ms_to_ds_dest = ms_dest & {5{ms_valid & ms_gr_we}};
assign ms_to_ds_result = ms_final_result; //改动
assign ws_to_ds_dest = ws_dest & {5{ws_valid}};//修改：寄存器号传递
assign ws_to_ds_dest = ws_dest & {5{ws_valid & ws_gr_we}};
assign ws_to_ds_result = ws_final_result; //改动
原因说明
仿真里 wb_rf_wdata 打成 0xxxxxxxxx，表示写回数据里有 X（未定义），通常来自：

mem_stage.v 流水线寄存器用了阻塞赋值 =
在 always @(posedge clk) 里对 es_to_ms_bus_r 使用 = 会与 <= 混用，容易造成仿真上的时序/竞争，和真实寄存器行为不一致，可能把错误或未稳定的数据送进 MEM/WB。

数据前递用的“目的寄存器”未按是否写回屏蔽
es_to_ds_dest / ms_to_ds_dest / ws_to_ds_dest 原先只按 *_valid 屏蔽。像 st.w 这类指令不写 GPR，但指令里仍有 rd 字段，EXE/MEM/WB 里 dest 仍可能是某个寄存器号。后面的指令若读同一寄存器，会误以为前面在写回而从前递取数，实际取到的是 store 的地址计算结果或其它无关值，在复杂程序里可能进一步导致异常路径或未初始化读，最终在写回上出现 X。
