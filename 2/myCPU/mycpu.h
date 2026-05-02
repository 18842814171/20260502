`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       34
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 153  // 增加1位用于store_type
    `define ES_TO_MS_BUS_WD 105   // add 1 bit: mem_we into ES->MS bus
    `define MS_TO_WS_BUS_WD 70
    `define WS_TO_RF_BUS_WD 38
`endif
