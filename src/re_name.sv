// Author: Florian Zaruba, ETH Zurich
// Date: 03.10.2017
// Description: Re-name registers
//
//
// Copyright (C) 2017 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Bug fixes and contributions will eventually be released under the
// SolderPad open hardware license in the context of the PULP platform
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
// University of Bologna.
//

import ariane_pkg::*;

module re_name (
    input  logic                                   clk_i,    // Clock
    input  logic                                   rst_ni,   // Asynchronous reset active low
    input  logic                                   flush_i,  // Flush renaming state
    // from/to scoreboard
    input  scoreboard_entry_t                      issue_instr_i,
    input  logic                                   issue_instr_valid_i,
    output logic                                   issue_ack_o,
    // from/to issue and read operands
    output scoreboard_entry_t                      issue_instr_o,
    output logic                                   issue_instr_valid_o,
    input  logic                                   issue_ack_i
);

    // pass through handshaking signals
    assign issue_instr_valid_o = issue_instr_valid_i;
    assign issue_ack_o         = issue_ack_i;

    // keep track of re-naming data structures
    logic [31:0] re_name_table_gpr_n, re_name_table_gpr_q;

    // -------------------
    // Re-naming
    // -------------------
    always_comb begin
        // MSB of the renamed source register addresses
        logic name_bit_rs1, name_bit_rs2, name_bit_rd;

        // default assignments
        re_name_table_gpr_n = re_name_table_gpr_q;
        issue_instr_o       = issue_instr_i;

        if (issue_ack_i) begin
            // if we acknowledge the instruction tic the corresponding destination register
            re_name_table_gpr_n[issue_instr_i.rd] = re_name_table_gpr_q[issue_instr_i.rd] ^ 1'b1;
        end

        // select name bit according to the register file used for source operands
        name_bit_rs1 = re_name_table_gpr_q[issue_instr_i.rs1];
        name_bit_rs2 = re_name_table_gpr_q[issue_instr_i.rs2];

        // select name bit according to the state it will have after renaming
        name_bit_rd = re_name_table_gpr_q[issue_instr_i.rd] ^ (issue_instr_i.rd != '0); // don't rename x0

        // re-name the source registers
        issue_instr_o.rs1 = { ENABLE_RENAME & name_bit_rs1, issue_instr_i.rs1[4:0] };
        issue_instr_o.rs2 = { ENABLE_RENAME & name_bit_rs2, issue_instr_i.rs2[4:0] };

        // re-name the destination register
        issue_instr_o.rd = { ENABLE_RENAME & name_bit_rd, issue_instr_i.rd[4:0] };

        // we don't want to re-name gp register zero, it is non-writeable anyway
        re_name_table_gpr_n[0] = 1'b0;

        // Handle flushes
        if (flush_i) begin
            re_name_table_gpr_n = '0;
        end

    end

    // -------------------
    // Registers
    // -------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            re_name_table_gpr_q <= '0;
        end else begin
            re_name_table_gpr_q <= re_name_table_gpr_n;
        end
    end
endmodule
