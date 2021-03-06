// cpu_execute.v - The moxie execute stage
//
// Copyright (c) 2010, 2011, 2012 Anthony Green.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
// 
// The above named program is free software; you can redistribute it
// and/or modify it under the terms of the GNU General Public License
// version 2 as published by the Free Software Foundation.
// 
// The above named program is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
// 02110-1301, USA.

`include "defines.h"

module cpu_execute (/*AUTOARG*/
  // Outputs
  register_wea_o, register_web_o, register0_write_index_o,
  register1_write_index_o, pipeline_control_bits_o, memory_address_o,
  reg0_result_o, reg1_result_o, mem_result_o, riA_o, riB_o, PC_o,
  flush_o, branch_flag_o, branch_target_o,
  // Inputs
  rst_i, clk_i, flush_i, riA_i, riB_i, regA_i, regB_i,
  pipeline_control_bits_i, register0_write_index_i,
  register1_write_index_i, operand_i, op_i, sp_i, fp_i, PC_i,
  pcrel_offset_i
  );

  parameter [1:0] STATE_READY = 2'b00,
    STATE_JSR1 = 2'b01,
    STATE_RET1 = 2'b10;

  // --- Clock and Reset ------------------------------------------
  input  rst_i, clk_i;

  // --- Pipeline interlocking ------------------------------------
  input  flush_i;
    
  // --- Inputs ---------------------------------------------------
  input [3:0] riA_i;
  input [3:0] riB_i;
  input [31:0] regA_i;
  input [31:0] regB_i;
  input [`PCB_WIDTH-1:0] pipeline_control_bits_i;
  input [3:0]  register0_write_index_i;
  input [3:0]  register1_write_index_i;
  input [31:0] operand_i;
  input [5:0]  op_i;
  input [31:0] sp_i;
  input [31:0] fp_i;
  input [31:0] PC_i;
  input [9:0]  pcrel_offset_i;
  
  // --- Outputs --------------------------------------------------
  output register_wea_o;
  output register_web_o;
  output [3:0] register0_write_index_o;
  output [3:0] register1_write_index_o;
  output [`PCB_WIDTH-1:0] pipeline_control_bits_o;
  output [31:0] memory_address_o;  
  output [31:0] reg0_result_o;
  output [31:0] reg1_result_o;
  output [31:0] mem_result_o;
  output [3:0] riA_o;
  output [3:0] riB_o;
  output [31:0] PC_o;
      

  output [0:0] flush_o;
  reg [0:0]    flush_o;

  reg [0:4]   CC_result;
  
  output       branch_flag_o;
  output [31:0] branch_target_o;

  reg [0:0] 	branch_flag_o;
  reg [31:0] 	branch_target_o;

  reg [3:0]    register0_write_index_o;
  reg [3:0]    register1_write_index_o;
  reg [`PCB_WIDTH-1:0] 	pipeline_control_bits_o;
  reg [31:0] 	memory_address_o;
  reg [31:0] 	reg0_result_o;
  reg [31:0] 	reg1_result_o;
  reg [31:0] 	mem_result_o;

  reg [31:0] 	PC_o;

  reg [1:0] 	current_state, next_state;
  
  assign riA_o = riA_i;
  assign riB_o = riB_i;

   reg [0:0] 	register_wea_o;
   reg [0:0] 	register_web_o;

  wire cc_eq, cc_gt, cc_lt, cc_gtu, cc_ltu;
  wire [31:0] cc_AsubB;
  wire [31:0] cc_BsubA;

  assign cc_AsubB = regA_i - regB_i;
  assign cc_BsubA = regB_i - regA_i;
   
  assign cc_eq = regA_i == regB_i;
  assign cc_lt = regA_i[31] ^ regB_i[31] ? regA_i[31] : cc_AsubB[31];
  assign cc_gt = regA_i[31] ^ regB_i[31] ? regB_i[31] : cc_BsubA[31];
  assign cc_gtu = regA_i > regB_i;
  assign cc_ltu = regA_i < regB_i;
  
  wire branch_condition;
  assign branch_condition =
       ((op_i == `OP_BEQ) & CC_result[0])
       | ((op_i == `OP_BNE) & !CC_result[0])
       | ((op_i == `OP_BLT) & CC_result[1])
       | ((op_i == `OP_BLTU) & CC_result[3])
       | ((op_i == `OP_BGT) & CC_result[2])
       | ((op_i == `OP_BGTU) & CC_result[4])
       | ((op_i == `OP_BLE) & (CC_result[0] | CC_result[1]))
       | ((op_i == `OP_BGE) & (CC_result[0] | CC_result[2]))
       | ((op_i == `OP_BLEU) & (CC_result[0] | CC_result[3]))
       | ((op_i == `OP_BGEU) & (CC_result[0] | CC_result[4]));

  wire[31:0] pcrel_branch_target;
  assign pcrel_branch_target = {20'b0,pcrel_offset_i,1'b0} + PC_i + 32'd2;

   
   
  wire [7:0] incdec_value = pcrel_offset_i[7:0];
    
  always @(posedge clk_i)
    begin
       if (! rst_i) begin
	  register_wea_o = pipeline_control_bits_i[`PCB_WA] ;
	  register_web_o = pipeline_control_bits_i[`PCB_WB];
       end
    end

   always @(posedge clk_i)
     begin
       flush_o <= rst_i ? 1'b0 
		  : flush_i 
		    | branch_condition 
		    | (op_i == `OP_JMPA) 
		    | (current_state == STATE_JSR1);
     end
   
  always @(posedge rst_i or posedge clk_i)
    if (rst_i) begin
      pipeline_control_bits_o <= 5'b00000;
      branch_flag_o <= 0;
      current_state <= STATE_READY;
      next_state <= STATE_READY;
    end else begin
       branch_flag_o <= branch_condition | (op_i == `OP_JMPA) | (current_state == STATE_JSR1);
       current_state <= branch_condition ? STATE_READY : next_state;
       if (branch_flag_o | flush_i)
         begin
	    /* We've just branched, so ignore any incoming instruction.  */
	    pipeline_control_bits_o <= 5'b00000;
 	    next_state <= STATE_READY; 
	 end
       else begin
	  pipeline_control_bits_o <= pipeline_control_bits_i;
	  PC_o <= PC_i;
	  case (current_state)
	    STATE_READY:
	      begin
		 case (op_i)
		   `OP_ADD_L:
		  begin
		    reg0_result_o <= regA_i + regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_AND:
		  begin
		    reg0_result_o <= regA_i & regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_ASHL:
		  begin
		     reg0_result_o <= regA_i <<< regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_ASHR:
		  begin
		     reg0_result_o <= regA_i >>> regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_BAD:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_BEQ:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BGE:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BGEU:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BGT:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BGTU:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BLE:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BLEU:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BLT:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BLTU:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BNE:
		  begin
		    branch_target_o <= pcrel_branch_target;
		    next_state <= STATE_READY;
		  end
		`OP_BRK:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_CMP:
		  begin
		    CC_result <= {cc_eq, cc_lt, cc_gt, cc_ltu, cc_gtu};
		    next_state <= STATE_READY;
		  end
		`OP_DEC:
		  begin
		    reg0_result_o <= regA_i - incdec_value;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_DIV_L:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_GSR:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_INC:
		  begin
		    reg0_result_o <= regA_i + incdec_value;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_JMP:
		  begin
		    branch_target_o <= regA_i;
		    next_state <= STATE_READY;
		  end
		`OP_JMPA:
		  begin
		    branch_target_o <= operand_i;
		    next_state <= STATE_READY;
		  end
		`OP_JSR:
		  begin
		    // Decrement $sp by 8 bytes and store the return address.
		    reg0_result_o <= sp_i - 8;
		    memory_address_o <= sp_i - 8;
		    mem_result_o <= PC_i+6;
		    register0_write_index_o <= 1; // $sp
		    next_state <= STATE_JSR1;
		  end
		`OP_JSRA:
		  begin
		    next_state <= STATE_JSR1;
		  end
		`OP_LDA_B:
		  begin
		    memory_address_o <= operand_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDA_L: 
		  begin
		    memory_address_o <= operand_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDA_S:
		  begin
		    memory_address_o <= operand_i;
		    next_state <= STATE_READY;
		  end
		`OP_LD_B:
		  begin
		    memory_address_o <= regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDI_B:
		  begin
		    reg0_result_o <= operand_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDI_L:
		  begin
		    reg0_result_o <= operand_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDI_S:
		  begin
		    reg0_result_o <= operand_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_LD_L:
		  begin
		    memory_address_o <= regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDO_B:
		  begin
		    memory_address_o <= operand_i + regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDO_L:
		  begin
		    memory_address_o <= operand_i + regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LDO_S:
		  begin
		    memory_address_o <= operand_i + regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LD_S:
		  begin
		    memory_address_o <= regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_LSHR:
		  begin
		    reg0_result_o <= regA_i >> regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_MOD_L:
		  begin
		    // FIXME reg0_result_o <= regA_i % regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_MOV:
		  begin
		    reg0_result_o <= regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_MUL_L:
		  begin
		    reg0_result_o <= regA_i * regB_i;
		    next_state <= STATE_READY;
		  end
		`OP_NEG:
		  begin
		    reg0_result_o <= -regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_NOP:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_NOT:
		  begin
		    reg0_result_o <= !regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_OR:
		  begin
		    reg0_result_o <= regA_i | regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_POP:
		  begin
		    // Decrement pointer register by 4 bytes.
		    memory_address_o <= regA_i;
		    reg1_result_o <= regA_i - 4;
		    register0_write_index_o <= register1_write_index_i;
		    register1_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_PUSH:
		  begin
		    // Decrement pointer register by 4 bytes.
		    reg0_result_o <= regA_i - 4;
		    memory_address_o <= regA_i - 4;
		    mem_result_o <= regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_RET:
		  begin
		    // Increment $sp by 8
		    memory_address_o <= sp_i;
		    reg0_result_o <= sp_i + 8;
		    register0_write_index_o <= 1; // $sp
		    next_state <= STATE_RET1;
		  end
		`OP_SSR:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_STA_B:
		  begin
		    mem_result_o <= regA_i;
		    next_state <= STATE_READY;
		  end
		`OP_STA_L:
		  begin
		    mem_result_o <= regA_i;
		    memory_address_o <= operand_i;
		    next_state <= STATE_READY;
		  end
		`OP_STA_S:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_ST_B:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_ST_L:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_STO_B:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_STO_L:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_STO_S:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_ST_S:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_SUB_L:
		  begin
		    reg0_result_o <= regA_i - regB_i;
		    register0_write_index_o <= register0_write_index_i;
		    next_state <= STATE_READY;
		  end
		`OP_SWI:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_UDIV_L:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_UMOD_L:
		  begin
		    next_state <= STATE_READY;
		  end
		`OP_XOR:
		  begin
		    reg0_result_o <= regA_i ^ regB_i;
		    register0_write_index_o <= register0_write_index_i;
		  end
	      endcase // case (op_i)
	    end // case: STATE_READY
	  STATE_JSR1:
	    begin
	      // Decrement $sp by 4 bytes.
	      reg0_result_o <= sp_i - 4;
	      memory_address_o <= sp_i - 4;
	      mem_result_o <= fp_i;
	      register0_write_index_o <= 1; // $sp
	      branch_target_o <= operand_i;
	      next_state <= STATE_READY;
	    end
	  STATE_RET1:
	    begin
	      // Increment $sp by 4 bytes.
	      reg0_result_o <= sp_i + 4;
	      memory_address_o <= sp_i + 4;
	       pipeline_control_bits_o <= 5'b10000;
	      // This is all wrong
	      register0_write_index_o <= 1; // $sp
	      branch_target_o <= operand_i;
	      next_state <= STATE_READY;
	    end
	endcase
       end
    end
endmodule // cpu_execute;
