//====================================================================
//  Snake-Game-on-FPGA
//  Minimal Verilog Top Module for HDMI Output (1280x720 @ 60Hz)
//
//  Author: Jiacheng Guo
//  Date:   2025-06-05
//
//  Description:
//    Standalone top-level Verilog module for a Snake game with HDMI display.
//    Developed as a course project for "Chip & System II: Verilog and FPGA Design".
//    All game logic and video timing are implemented here.
//
//  Revision History:
//    - v1.0: Initial version (640x480@60Hz, CELL=20, GRID=32x24)
//    - v2.0: Upgrade to 1280x720@60Hz, CELL=40, GRID=32x18, new video timing parameters
//    - v2.1: Fix is_snake out-of-bounds bug, unify iteration logic
//
//  License: MIT License. See repository LICENSE file for details.
//====================================================================

module top(
    input  wire         sys_clk,      // External system clock
    input  wire         rst_n,        // Active-low reset

    // ─── 4-way directional buttons (active low) ─────────────
    input  wire         key_up,
    input  wire         key_down,
    input  wire         key_left,
    input  wire         key_right,

    // ─── HDMI-TMDS output ──────────────────────────────────
    output wire         tmds_clk_p,
    output wire         tmds_clk_n,
    output wire [2:0]   tmds_data_p,
    output wire [2:0]   tmds_data_n
);

//━━━━━━━━━━━━━ Clock PLL & BUFG ━━━━━━━━━━━━━
wire sys_clk_g, video_clk_w, video_clk5x_w, video_clk, video_clk5x;

GTP_CLKBUFG u_sys_bufg  (.CLKIN(sys_clk),        .CLKOUT(sys_clk_g ));
GTP_CLKBUFG u_v5_bufg   (.CLKIN(video_clk5x_w),  .CLKOUT(video_clk5x));
GTP_CLKBUFG u_v_bufg    (.CLKIN(video_clk_w),    .CLKOUT(video_clk ));

video_pll u_video_pll(
    .pll_rst (1'b0),
    .clkin1  (sys_clk_g),
    .pll_lock(),
    .clkout0 (video_clk5x_w),
    .clkout1 (video_clk_w)
);

//━━━━━━━━━━━━━ Video timing (1280×720) ━━━━━━━━━━━━━
localparam H_SYNC  =  40, H_BACK  = 220, H_DISP = 1280, H_FRONT = 110, H_TOTAL = 1650;
localparam V_SYNC  =   5, V_BACK  =  20, V_DISP =  720, V_FRONT =   5, V_TOTAL  =  750;

reg  [11:0] h_cnt;      // Range: 0..1649
reg  [10:0] v_cnt;      // Range: 0..749
wire        hs, vs, de;
wire [10:0] x_pix, y_pix;

always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)            h_cnt <= 0;
    else if(h_cnt==H_TOTAL-1) h_cnt <= 0;
    else                  h_cnt <= h_cnt + 1;
end

always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)           v_cnt <= 0;
    else if(h_cnt==H_TOTAL-1) begin
        if(v_cnt==V_TOTAL-1) v_cnt <= 0;
        else                 v_cnt <= v_cnt + 1;
    end
end

assign hs = (h_cnt <  H_SYNC);
assign vs = (v_cnt <  V_SYNC);
assign de = (h_cnt>=H_SYNC+H_BACK && h_cnt< H_SYNC+H_BACK+H_DISP &&
             v_cnt>=V_SYNC+V_BACK && v_cnt< V_SYNC+V_BACK+V_DISP);

assign x_pix = h_cnt - (H_SYNC + H_BACK);
assign y_pix = v_cnt - (V_SYNC + V_BACK);

//━━━━━━━━━━━━━ Snake game logic ━━━━━━━━━━━━━
localparam CELL    = 40;            // Cell size: 40×40 pixels
localparam GRID_W  = H_DISP / CELL; // 1280/40 = 32 columns
localparam GRID_H  = V_DISP / CELL; //  720/40 = 18 rows
localparam MAX_LEN = 128;           // Max snake length (cells)

// --- Register declarations ---
// Snake body coordinates (grid): 0..31, 0..17
reg  [4:0] snake_x [0:MAX_LEN-1];
reg  [4:0] snake_y [0:MAX_LEN-1];
reg  [7:0] snake_len;               // Current length (init 4, max 127)
reg  [4:0] food_x, food_y;          // Food position 0..31 / 0..17
reg  [1:0] dir;                     // Direction: 0=Up 1=Down 2=Left 3=Right
reg        is_snake;                // Whether current cell is part of snake body
integer    i;                       // Loop index (internal only)

// --- LFSR-based pseudo-random generator for food placement ---
reg [4:0] lfsr_x, lfsr_y;
always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n) begin
        lfsr_x <= 5'b10101;
        lfsr_y <= 5'b01011;
    end
    else if(game_tick && snake_x[0]==food_x && snake_y[0]==food_y) begin
        // Update only when food is eaten
        lfsr_x <= {lfsr_x[3:0], lfsr_x[4]^lfsr_x[2]};
        lfsr_y <= {lfsr_y[3:0], lfsr_y[4]^lfsr_y[1]};
    end
end

// --- game clock divider ---
reg [22:0] div_cnt;
wire       game_tick = (div_cnt == 0);
always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n)       div_cnt <= 0;
    else             div_cnt <= div_cnt + 1;
end

// --- Main FSM: initialize on reset, update on every game_tick ---
always @(posedge video_clk or negedge rst_n) begin
    if(!rst_n) begin
        // --- Reset: initialize snake at (14,9), length=4, facing right ---
        snake_len <= 8'd4;
        for(i=0; i<MAX_LEN; i=i+1) begin
            snake_x[i] <= 5'd14 - i;  // i=0 -> (14,9), i=1 -> (13,9), ...
            snake_y[i] <= 5'd9;       // All on row y=9
        end
        dir    <= 2'd3;               // Start moving right
        food_x <= 5'd20;              // Arbitrary initial food position
        food_y <= 5'd6;
    end
    else if(game_tick) begin
        // -- 1. Direction update (no 180° reversal) --
        if(!key_up    && dir!=2'd1) dir <= 2'd0;
        if(!key_down  && dir!=2'd0) dir <= 2'd1;
        if(!key_left  && dir!=2'd3) dir <= 2'd2;
        if(!key_right && dir!=2'd2) dir <= 2'd3;

        // -- 2. Move body (from tail to head, i=127..1) --
        for(i = MAX_LEN-1; i>0; i=i-1) begin
            if(i < snake_len) begin
                snake_x[i] <= snake_x[i-1];
                snake_y[i] <= snake_y[i-1];
            end
            else begin
                snake_x[i] <= snake_x[i]; // Do not update if outside body
                snake_y[i] <= snake_y[i];
            end
        end

        // -- 3. Update head coordinate (edge wrapping) --
        case(dir)
            2'd0: snake_y[0] <= (snake_y[0]==0)         ? GRID_H-1 : snake_y[0]-1; 
            2'd1: snake_y[0] <= (snake_y[0]==GRID_H-1)  ? 0        : snake_y[0]+1;
            2'd2: snake_x[0] <= (snake_x[0]==0)         ? GRID_W-1 : snake_x[0]-1;
            2'd3: snake_x[0] <= (snake_x[0]==GRID_W-1)  ? 0        : snake_x[0]+1;
        endcase

        // -- 4. Grow if head eats food, then generate new food --
        if(snake_x[0]==food_x && snake_y[0]==food_y) begin
            if(snake_len < MAX_LEN-1)
                snake_len <= snake_len + 1;
            // LFSR output, modulo grid size
            food_x <= lfsr_x % GRID_W;  // lfsr_x ∈ [0..31], GRID_W=32
            food_y <= lfsr_y % GRID_H;  // lfsr_y ∈ [0..31], GRID_H=18
        end
    end
end

//━━━━━━━━━━━━━ Combinational logic: is the pixel a snake body? ━━━━━━━━━━━━━
reg [7:0] video_r, video_g, video_b;
wire [4:0] cell_x = x_pix / CELL;  // Current cell X in grid (0..31)
wire [4:0] cell_y = y_pix / CELL;  // Current cell Y in grid (0..17)

always @* begin
    // -- Loop over 0..MAX_LEN-1, if i < snake_len and (x,y) matches, it's a snake body cell --
    is_snake = 1'b0;
    for(i = 0; i < MAX_LEN; i = i + 1) begin
        if(i < snake_len) begin
            if(cell_x == snake_x[i] && cell_y == snake_y[i]) begin
                is_snake = 1'b1;
            end
        end
    end
end

always @(posedge video_clk) begin
    if(!de) begin
        // Non-display region: black
        video_r <= 8'h00; 
        video_g <= 8'h00; 
        video_b <= 8'h00;
    end
    else if(cell_x == food_x && cell_y == food_y) begin
        // Food: red
        video_r <= 8'hFF; 
        video_g <= 8'h00; 
        video_b <= 8'h00;
    end
    else if(is_snake) begin
        // Snake body: green
        video_r <= 8'h00; 
        video_g <= 8'hFF; 
        video_b <= 8'h00;
    end
    else begin
        // Background: dark blue
        video_r <= 8'h00; 
        video_g <= 8'h00; 
        video_b <= 8'h20;
    end
end

//━━━━━━━━━━━━━ DVI/HDMI Encoding ━━━━━━━━━━━━━
dvi_encoder u_dvi(
    .pixelclk    (video_clk), 
    .pixelclk5x  (video_clk5x), 
    .rstin       (~rst_n),
    .blue_din    (video_b),
    .green_din   (video_g),
    .red_din     (video_r),
    .hsync       (hs),
    .vsync       (vs),
    .de          (de),
    .tmds_clk_p  (tmds_clk_p),
    .tmds_clk_n  (tmds_clk_n),
    .tmds_data_p (tmds_data_p),
    .tmds_data_n (tmds_data_n)
);

endmodule
