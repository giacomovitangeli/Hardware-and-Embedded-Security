`include"aes_sbox.sv"
`include"LH_functions.sv"

`define NULL_CHAR 8'h00

module light_hash (
	// aggiungere head e tail, perchè altrimenti escludiamo dei valori possibili
	input              clk			    //clock
	,input             rst_n			//reset
	,input		[7:0]  message_byte	    //8-bit input
	,input			   message_valid	//define the validity of the input 8-bit message
	,input 		[1:0]  state			//state = 2'b00 => head of the messagge, 2'b01 => tail, 2'b10 message e default 2'b11
	,output reg [63:0] digest	        //64-bit digest output --> composition of 8 blocks H[i] of 8-bit
	,output reg		   digest_ready	    //hash function of the input message is completed
	);


// ---------------------------------------------------------------------------
// VARIABLES
// ---------------------------------------------------------------------------


//init digest
//localparam reg [7:0] restore_digest [0:7] = '{8'h34, 8'h55, 8'h0F, 8'h14, 8'hDA, 8'hC0, 8'h2B, 8'hEE};

// Initialize digest
function unpacked_arr restore_digest;
    restore_digest[0] = 8'h34;
	restore_digest[1] = 8'h55;
	restore_digest[2] = 8'h0F;
	restore_digest[3] = 8'h14;
	restore_digest[4] = 8'hDA;
	restore_digest[5] = 8'hC0;
	restore_digest[6] = 8'h2B;
	restore_digest[7] = 8'hEE;
endfunction

//64-bit temporary digest
reg [7:0] digest_tmp[0:7];
//left shift suport register
reg [7:0] shifter;
//enable/disable next message_byte as input
reg next_byte = 1'b0;
// enable output sequential always
reg tmp_digest_ready;
//int to perform the aes_sbox function
int row, column, index, r;



// ---------------------------------------------------------------------------
// LOGIC DESIGN
// ---------------------------------------------------------------------------


// compute digest
function unpacked_arr update_digest(input [7:0] digest[0:7]);
  for (int j = 0; j < 8; j++) begin
      update_digest[j] = (digest[(j + 2) % 8] ^ message_byte);
	shifter = update_digest[j];
	update_digest[j] = shift_digest(shifter, j);
      // 4 MSb and the 4 LSb of input byte as row and column of sbox lut to substitute it
      row = update_digest[j][7:4];
      column = update_digest[j][3:0];
      index = (row * 16) + column;
      update_digest[j] = aes128_sbox(index);
end
endfunction

//  combinational always
always @ (*) begin

	if(message_valid) begin
		case(state)
			head : begin
				tmp_digest_ready = 1'b0;
				digest_tmp = restore_digest();
				next_byte = 1'b0;
				r = 0;
			end
			tail : begin
				tmp_digest_ready = 1'b1;
				next_byte = 1'b0;
				r = 0;
			end
			message : begin
				for(r = 0; r < 32; r++) begin
					if (r == 0) begin
						next_byte = 1'b1;
					end
					digest_tmp = update_digest(digest_tmp);
				end
				// put to 0 and then to 1 in next iteration to wake up the tb
				next_byte = 1'b0;
				tmp_digest_ready = 1'b0;

			end
			default : begin
				tmp_digest_ready = 1'b0;
				$display("Error default case");
				r = 0;
			end
		endcase
	end
	else begin
		tmp_digest_ready = 1'b0;
		next_byte = 1'b1;
		r = 0;
	end
end

// sequential always
always @(posedge clk or negedge rst_n) begin
	// Handling the rst_n signal
	if(!rst_n) begin
		digest_ready <= 1'b0;
		digest <= `NULL_CHAR;
	end
    else begin
		// Handling outputs of the module
		if(tmp_digest_ready) begin
			// Branch in which the digest has been computed properly
			digest_ready <= 1'b1;
			digest <= get_digest(digest_tmp);
		end
		else begin
			// Branch in which the digest hasn't been computed properly
			digest_ready <= 1'b0;
			digest <= `NULL_CHAR;
		end
	end
end





endmodule
