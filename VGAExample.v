`timescale 1ns / 1ps

module VGAExample( Switch, button_in, led, en, SevenSeg_g1, SevenSeg_g0, ps2_data, ps2_clk, clk, rst, hsync, vsync, vga_r, vga_g, vga_b);
   input             ps2_data, Switch;
   input             clk, rst, ps2_clk;
   input [4:0]       button_in;
   output reg [15:0] led;
   output reg [7:0]  SevenSeg_g0, SevenSeg_g1;
   output reg [7:0]  en;
   output            hsync,vsync;
   output [3:0]      vga_r, vga_g, vga_b;     
   wire              pclk;
   wire              valid;
   wire [9:0]        h_cnt,v_cnt;
   reg [11:0]        vga_data;
   
   wire [7:0]        Key_data;
   wire              clk1, clk2, clk3, clk4;
   wire [1:0]        outdata;//keyboard-keyboard module 給值
   reg               enkeyboard; 
   keyboard k0 ( .reset(rst), .enkeyboard(enkeyboard), .ps2_clk(ps2_clk), .ps2_data(ps2_data), .outdata(outdata) );
   
   
   wire [11:0]  person_rom_dout, bomb1_rom_dout,
                bombF_rom_dout, bombQ_rom_dout, bombW_rom_dout, bombE_rom_dout,
                block_rom_dout, house_rom_dout, tree_rom_dout, target_rom_dout, 
                zero_rom_dout, one_rom_dout, two_rom_dout, three_rom_dout, four_rom_dout;
   reg [10:0]   rom_addr[1:30], ROM_addr;//30*50=1500  <  2^11=2048
   reg [10:0]   block_addr[11:0], tree_addr[7:0], house_addr[9:0];
   reg [12:0]   zero_addr, one_addr, two_addr, three_addr, four_addr;// 80*100=19200 < 2^13=32768
   reg [11:0]   bomb1_addr, bombF_addr, bombQ_addr, bombW_addr, bombE_addr;//// 第一關&第二關炸彈
   wire line_area;//畫線 
   wire person_logo_area,
        bomb_logo_area,
        block1_logo_area, block2_logo_area, block3_logo_area, block4_logo_area,
        house1_logo_area, house2_logo_area, house3_logo_area,
        tree1_logo_area, tree2_logo_area, tree3_logo_area,
        target_logo_area,
        bomb_area, bombF_area, bombQ_area, bombW_area, bombE_area,//// 第一關&第二關炸彈
        zero_logo_area, one_logo_area, two_logo_area, three_logo_area, four_logo_area;
  reg   person_explode, target_explode;
        
   // 關卡二的//          障礙物區域
   reg       block_area[11:0],// 12 個箱子
             house_area[9:0],// 10個房子
             tree_area[7:0];//8棵樹

   reg block1_explode, block2_explode, block3_explode, block4_explode;
   reg [9:0] person_x, person_y, person_next_x, person_next_y,
             bomb_x, bomb_y,
             block1_x, block1_y, block2_x, block2_y, block3_x, block3_y, block4_x, block4_y,
             house1_x, house1_y, house2_x, house2_y, house3_x, house3_y,
             tree1_x, tree1_y, tree2_x, tree2_y, tree3_x, tree3_y,
             target_x, target_y,
             time_x, time_y; 
             
   // 關卡二的//          10bits 的障礙物座標
   reg [9:0]         block_x[11:0], block_y[11:0],// 12個箱子
                     house_x[9:0], house_y[9:0],// 10個房子
                     tree_x[7:0], tree_y[7:0];//8棵樹
    wire [11:0]      poison_rom_dout, Q_rom_dout, W_rom_dout, E_rom_dout, help_rom_dout;  
    wire             poison_area, Q1_area, Q2_area, W1_area, W2_area, E1_area, E2_area, help_area;
    reg [9:0]        poison_x, poison_y, poison_next_x,
                     Q1_x, Q1_y, Q2_x, Q2_y, W1_x, W1_y, W2_x, W2_y, E1_x, E1_y, E2_x, E2_y, help_x, help_y,
                     bombF_x, bombF_y, bombQ_x, bombQ_y, bombW_x, bombW_y, bombE_x, bombE_y;/////第二關炸彈
    reg              block_explode[11:0], Q_explode[2:1], W_explode[2:1], E_explode[2:1];     ///  1：炸掉
//    reg              block_wrong[11:0], Q_wrong[2:1], W_wrong[2:1], E_wrong[2:1];     ///  1：炸掉    
    //reg person_pois; //1：人碰到毒藥
   
   parameter show_0 = 8'b1111_1100, show_1 = 8'b0110_0000, show_2 = 8'b1101_1010, show_3 = 8'b1111_0010, show_4 = 8'b0110_0110, 
             show_5 = 8'b1011_0110, show_6 = 8'b1011_1110, show_7 = 8'b1110_0000, show_8 = 8'b1111_1110, show_9 = 8'b1111_0110, show_none = 8'd0;
                                  
   dcm_25M u0(.clk_in1(clk),.clk_out1(pclk),.reset(!rst));
   
        // 除頻
   reg [26:0] counter27 = 27'b0;
   always @(posedge clk, negedge rst)
    begin
        if (!rst) begin counter27 <= 1'b0; end
        else begin counter27 <= counter27 + 1'b1; end
    end        
    assign clk1 = counter27[14] ; // SevenSeg
    assign clk2 = counter27[25] ; // LED
    assign clk3 = counter27[26] ; // Bomb_Time,  Time_Count
    assign clk4 = counter27[13] ; //  Debounce 
    
      // 按鈕
   wire [4:0] button_out;   
   debounce u1 (.button_out(button_out[0] ), .button_in(button_in[0] ), .clk(clk4) );
   debounce u2 (.button_out(button_out[1] ), .button_in(button_in[1] ), .clk(clk4) );
   debounce u3 (.button_out(button_out[2] ), .button_in(button_in[2] ), .clk(clk4) );
   debounce u4 (.button_out(button_out[3] ), .button_in(button_in[3] ), .clk(clk4) );
   debounce u5 (.button_out(button_out[4] ), .button_in(button_in[4] ), .clk(clk4) );                          

                
                                                   
   reg [2:0] state = 3'd0, NS;
   parameter Stop = 3'd0, Move = 3'd1, Win = 3'd2, Die = 3'd3, Bomb = 3'd4;
   reg bomb_finish;
   reg bombF_finish, bombQ_finish, bombW_finish, bombE_finish;
   reg target; //剩餘救援目標
   reg [2:0] target2;//剩餘要消滅目標 (第二關)
   reg [4:0] times; //剩餘遊玩時間
   reg [7:0] times2; //剩餘遊玩時間 (第二關)
   reg [2:0] bomb_time;  // 炸彈倒數時間   
   reg [2:0] bombF_time, bombQ_time, bombW_time, bombE_time;  // 炸彈倒數時間 (第二關)
    always @(*)
    begin : COMB
        if (!rst) begin
            target = 1'b1;
            target2 = 3'd6;  
            end
        else begin
        if (Switch==0) begin             
            case (state)
                Stop : begin
                    if (button_out[0] == 1 || button_out[1] == 1 || button_out[2] == 1 || button_out[3] == 1 || button_out[4] == 1)begin NS = Move;  end
                    else begin NS = Stop; end
                    end
                Move : begin
                    if ( target == 1 & times == 0 ) begin NS = Die;  end
                    else if ( target_x == person_next_x & target_y == person_next_y & times > 0) begin target = 0; NS = Win; end
                    else if ( button_out[1] == 1 ) begin  NS = Bomb; end
                    else NS = Move;                                                                                                
                    end // end  State : Move 
                Bomb : begin
                    if ( (bomb_finish == 1 & person_explode == 1) | (bomb_finish == 1 & target_explode == 1)) NS = Die; 
                    else if (bomb_finish == 1) NS = Move;
                    else NS = Bomb;
                    end
                Win : begin
                        NS = Win;                
                    end // end  State : Win           
                Die : begin
                        NS = Die;
                    end // end  State : Die                        
                default : NS = Move;         
                endcase
        end//switch0 第一關 
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////         
        else begin//switch1 第二關 ////////////////////////////////
            case (state)
                Stop : begin
                    if (button_out[0] == 1 || button_out[1] == 1 || button_out[2] == 1 || button_out[3] == 1 || button_out[4] == 1)begin NS = Move;  end
                    else begin NS = Stop; end
                    end
                Move : begin
                    target2 = 6-Q_explode[1]-Q_explode[2]-W_explode[1]-W_explode[2]-E_explode[1]-E_explode[2];
                    if ( target2 >= 1 & times2 == 0 ) begin NS = Die;  end //時間沒了
                    else if ( poison_next_x == person_next_x & poison_y == person_next_y & times >= 0) begin NS = Die; end //毒藥碰到人
                    else if ( (Q_explode[1]==0 & Q1_x == person_next_x & Q1_y == person_next_y) ||
                              (Q_explode[2]==0 & Q2_x == person_next_x & Q2_y == person_next_y) ||
                              (W_explode[1]==0 & W1_x == person_next_x & W1_y == person_next_y) ||
                              (W_explode[2]==0 & W2_x == person_next_x & W2_y == person_next_y) ||
                              (E_explode[1]==0 & E1_x == person_next_x & E1_y == person_next_y) ||
                              (E_explode[2]==0 & E2_x == person_next_x & E2_y == person_next_y)    ) begin NS = Die; end //敵人碰到人
                    else if ( target2 == 0 & times > 0) begin  NS = Win; end //消滅全部敵人
                    else if ( button_out[1] == 1 ) begin  NS = Bomb; end
                    else NS = Move;                                                                                                                   
                    end // end  State : Move 
                Bomb : begin
                    if ( (bombF_finish == 1 & person_explode == 1) || (bombQ_finish == 1 & person_explode == 1) ||
                         (bombW_finish == 1 & person_explode == 1) || (bombE_finish == 1 & person_explode == 1) ) begin NS = Die; end//炸彈炸到人
                    else if ( poison_next_x == person_next_x & poison_y == person_next_y & times > 0) begin NS = Die; end //毒藥碰到人
                    else if ( ( (bombF_x == poison_x & bombF_y == poison_y) || // (bombF_time >0 | bombQ_time>0 | bombW_time>0 | bombE_time>0) &
                              (bombQ_x == poison_x & bombQ_y == poison_y) ||
                              (bombW_x == poison_x & bombW_y == poison_y) ||
                              (bombE_x == poison_x & bombE_y == poison_y)  ) ) begin NS = Die; end //毒藥碰到炸彈
                    else if ( (Q_explode[1]==0 & Q1_x == person_next_x & Q1_y == person_next_y) ||
                              (Q_explode[2]==0 & Q2_x == person_next_x & Q2_y == person_next_y) ||
                              (W_explode[1]==0 & W1_x == person_next_x & W1_y == person_next_y) ||
                              (W_explode[2]==0 & W2_x == person_next_x & W2_y == person_next_y) ||
                              (E_explode[1]==0 & E1_x == person_next_x & E1_y == person_next_y) ||
                              (E_explode[2]==0 & E2_x == person_next_x & E2_y == person_next_y)    ) begin NS = Die; end //敵人碰到人
                    else if ( target2 >= 1 & times2 == 0 ) begin NS = Die;  end //時間沒了  
                    else if ((bombF_finish == 1) || (bombQ_finish == 1) || (bombW_finish == 1) || (bombE_finish == 1)) begin NS = Move; end
                    else NS = Bomb;
                    end
                Win : begin
                        NS = Win;                
                    end // end  State : Win           
                Die : begin
                        NS = Die;
                    end // end  State : Die                        
                default : NS = Move;         
                endcase
         
        end               
        end// rst
    end // End COMB 

    //  炸彈時間  //  
    always @(posedge clk3, negedge rst)
    begin
        if (!rst) begin bomb_time <= 3'd4; bomb_finish <= 1'b0;
                        bombF_time <= 3'd2;bombQ_time <= 3'd3; bombW_time <= 3'd4; bombE_time <= 3'd5; //第二關
                        bombF_finish<= 1'b0; bombQ_finish<= 1'b0; bombW_finish<= 1'b0; bombE_finish<= 1'b0;  //第二關
                  end
        else begin
            if (NS == Bomb) begin                   
                if (Switch==0) begin 
                    if (bomb_time == 1) begin bomb_time <= 0; bomb_finish <= 1; end
                    else begin bomb_time <= bomb_time - 1'b1; end
                end
                else begin //第二關
                    case (outdata)
                    2'd0:begin 
                            if (bombF_time == 1) begin bombF_time <= 0; bombF_finish <= 1; end
                            else begin bombF_time <= bombF_time - 1'b1; end 
                          end     //炸彈種類1  
                    2'd1:begin
                            if (bombQ_time == 1) begin bombQ_time <= 0; bombQ_finish <= 1; end
                            else begin bombQ_time <= bombQ_time - 1'b1; end
                          end   //炸彈種類2  
                    2'd2:begin
                            if (bombW_time == 1) begin bombW_time <= 0; bombW_finish <= 1; end
                            else begin bombW_time <= bombW_time - 1'b1; end
                          end   //炸彈種類3  
                    2'd3:begin
                            if (bombE_time == 1) begin bombE_time <= 0; bombE_finish <= 1; end
                            else begin bombE_time <= bombE_time - 1'b1; end
                          end   //炸彈種類4  
                    default: ;
                    endcase
                end//第二關             
            end// NS = Bomb
            else begin bomb_finish <= 0; bomb_time <= 3'd4; 
                       bombF_time <= 3'd2;bombQ_time <= 3'd3; bombW_time <= 3'd4; bombE_time <= 3'd5; //第二關
                       bombF_finish<= 1'b0; bombQ_finish<= 1'b0; bombW_finish<= 1'b0; bombE_finish<= 1'b0; //第二關
            end
        end// rst
    end   //always

    reg [1:0] stronger;
    // 炸彈四周  // 
   always@(*)begin
       if (Switch==0) begin // 炸彈四周  // 第一關
            person_explode = ( state == Bomb & bomb_time == 0 & (
                                    (bomb_x + 40 == person_x & bomb_y == person_y) | (bomb_x - 40 == person_x & bomb_y == person_y) | 
                                    (bomb_x == person_x & bomb_y + 60 == person_y) | (bomb_x == person_x & bomb_y - 60 == person_y) |
                                     bomb_x == person_x & bomb_y == person_y) )? 1'b1:1'b0;
            target_explode = ( state == Bomb & bomb_time == 0 & (
                                    (bomb_x + 40 == target_x & bomb_y == target_y) | (bomb_x - 40 == target_x & bomb_y == target_y) | 
                                    (bomb_x == target_x & bomb_y + 60 == target_y) | (bomb_x == target_x & bomb_y - 60 == target_y) |
                                     bomb_x == target_x & bomb_y == target_y) )? 1'b1:1'b0; 
       end 
       else begin // 炸彈四周  // 第二關 // 
        if (stronger==1)                
            person_explode = ( state == Bomb & (
                                    (bombF_time == 0 & ((bombF_y == person_y) | 
                                    (bombF_x == person_x & bombF_y + 60 == person_y) | (bombF_x == person_x & bombF_y - 60 == person_y) ) ) |// bombF炸到人
                                    (bombQ_time == 0 & ((bombQ_y == person_y) | 
                                    (bombQ_x == person_x & bombQ_y + 60 == person_y) | (bombQ_x == person_x & bombQ_y - 60 == person_y)) ) |// bombQ炸到人
                                    (bombW_time == 0 & ((bombW_y == person_y) | 
                                    (bombW_x == person_x & bombW_y + 60 == person_y) | (bombW_x == person_x & bombW_y - 60 == person_y)) ) |// bombW炸到人
                                    (bombE_time == 0 & ((bombE_y == person_y) |  
                                    (bombE_x == person_x & bombE_y + 60 == person_y) | (bombE_x == person_x & bombE_y - 60 == person_y)) ) // bombE炸到人                    
                                     ) )? 1'b1:1'b0; 
        else                
            person_explode = ( state == Bomb & (
                                    (bombF_time == 0 & ((bombF_x + 40 == person_x & bombF_y == person_y) | (bombF_x - 40 == person_x & bombF_y == person_y) | 
                                    (bombF_x == person_x & bombF_y + 60 == person_y) | (bombF_x == person_x & bombF_y - 60 == person_y) |
                                    (bombF_x == person_x & bombF_y == person_y) )) |// bombF炸到人
                                    (bombQ_time == 0 & ((bombQ_x + 40 == person_x & bombQ_y == person_y) | (bombQ_x - 40 == person_x & bombQ_y == person_y) | 
                                    (bombQ_x == person_x & bombQ_y + 60 == person_y) | (bombQ_x == person_x & bombQ_y - 60 == person_y) |
                                    (bombQ_x == person_x & bombQ_y == person_y)) ) |// bombQ炸到人
                                    (bombW_time == 0 & ((bombW_x + 40 == person_x & bombW_y == person_y) | (bombW_x - 40 == person_x & bombW_y == person_y) | 
                                    (bombW_x == person_x & bombW_y + 60 == person_y) | (bombW_x == person_x & bombW_y - 60 == person_y) |
                                    (bombW_x == person_x & bombW_y == person_y)) ) |// bombW炸到人
                                    (bombE_time == 0 & ((bombE_x + 40 == person_x & bombE_y == person_y) | (bombE_x - 40 == person_x & bombE_y == person_y) | 
                                    (bombE_x == person_x & bombE_y + 60 == person_y) | (bombE_x == person_x & bombE_y - 60 == person_y) |
                                    (bombE_x == person_x & bombE_y == person_y)) ) // bombE炸到人                    
                                     ) )? 1'b1:1'b0;

                                
       end// switch1(第二關)
  end//always
 
 reg s;
 integer hh;          
always@ (posedge clk4 or negedge rst)
    begin : SEQ
                                  
        if (!rst) begin 
            state <= Stop; 
            person_next_x<=10'd6; person_next_y<=10'd426; 
            block1_explode <= 0; block2_explode <= 0; block3_explode <= 0; block4_explode <= 0;
            for (hh=0 ; hh<=11; hh=hh+1) block_explode[hh] <= 0;
            Q_explode[1] <= 0; Q_explode[2] <= 0;  W_explode[1] <= 0; W_explode[2] <= 0;  E_explode[1] <= 0; E_explode[2] <= 0;
            bomb_x <= 0; bomb_y <= 0;           
            enkeyboard<=1;
          //  target2<=3'd6;   
            stronger<=0; s<=0;
            end
        else begin
            state <= NS;  
            if(Switch==0)begin//關卡一                           
                case(NS)                           
                ///////            
                Move : begin                     
                    if (button_out[0] == 1'b1) begin // S0 : Right
                        if ( (block2_explode == 0 & person_x + 40 == block2_x & person_y == block2_y) || 
                             (block3_explode == 0 & person_x + 40 == block3_x & person_y == block3_y) || 
                             (block4_explode == 0 & person_x + 40 == block4_x & person_y == block4_y) || 
                             (person_x + 40 == house2_x & person_y == house2_y) || (person_x + 40 == house3_x & person_y == house3_y) || 
                             (person_x + 40 == tree3_x & person_y == tree3_y) || person_x > 10'd246) 
                            begin person_next_x <= person_x; end
                        else begin 
                            person_next_x <= person_x + 10'd40;
                            end
                    end 
                    else if (button_out[3] == 1'b1) begin // S3 : Left
                        if ( (block1_explode == 0 & person_x - 40 == block1_x & person_y == block1_y) || 
                             (block2_explode == 0 & person_x - 40 == block2_x & person_y == block2_y) || 
                             (block4_explode == 0 & person_x - 40 == block4_x & person_y == block4_y) || 
                             (person_x - 40 == house2_x & person_y == house2_y) || 
                             (person_x - 40 == tree1_x & person_y == tree1_y) || (person_x - 40 == tree2_x & person_y == tree2_y) || 
                             (person_x - 40 == tree3_x & person_y == tree3_y) || person_x < 10'd46) 
                            begin person_next_x <= person_x; end
                        else begin 
                            person_next_x <= person_x - 10'd40;
                            end
                    end                                      
                    else if (button_out[2] == 1'b1) begin // S2 : Down
                        if ( (block1_explode == 0 & person_y + 60 == block1_y & person_x == block1_x) || 
                             (block2_explode == 0 & person_y + 60 == block2_y & person_x == block2_x) ||  
                             (block3_explode == 0 & person_y + 60 == block3_y & person_x == block3_x) || 
                             (block4_explode == 0 & person_y + 60 == block4_y & person_x == block4_x) ||
                             (person_y + 60 == house1_y & person_x == house1_x) || (person_y + 60 == house2_y & person_x == house2_x) ||
                             (person_y + 60 == tree1_y & person_x == tree1_x) || (person_y + 60 == tree2_y & person_x == tree2_x) ||
                             (person_y + 60 == tree3_y & person_x == tree3_x) ||  person_y > 10'd366) 
                            begin person_next_y <= person_y; end
                        else begin 
                            person_next_y <= person_y + 10'd60;
                            end
                        end 
                    else if (button_out[4] == 1'b1) begin // S4 : Up
                        if ( (block1_explode == 0 & person_y - 60 == block1_y & person_x == block1_x) || 
                             (block2_explode == 0 & person_y - 60 == block2_y & person_x == block2_x) ||  
                             (block3_explode == 0 & person_y - 60 == block3_y & person_x == block3_x) || 
                             (block4_explode == 0 & person_y - 60 == block4_y & person_x == block4_x) ||
                             (person_y - 60 == house1_y & person_x == house1_x) || (person_y - 60 == house2_y & person_x == house2_x) ||
                             (person_y - 60 == house3_y & person_x == house3_x) || (person_y - 60 == tree2_y & person_x == tree2_x) ||
                              person_y < 10'd66) 
                            begin person_next_y <= person_y; end
                        else begin 
                            person_next_y <= person_y - 10'd60;
                            end
                        end 
                    else begin person_next_x <= person_x; person_next_y <= person_y; end  
                    
                    if (bomb_time == 4) begin bomb_x <= person_x; bomb_y <= person_y; end   //4
                    else if (bomb_time == 0) begin
                        if ( (bomb_x + 40 == block1_x & bomb_y == block1_y) | (bomb_x - 40 == block1_x & bomb_y == block1_y) | 
                                (bomb_x == block1_x & bomb_y + 60 == block1_y) | (bomb_x == block1_x & bomb_y - 60 == block1_y) )
                            begin block1_explode <= 1; end
                        if ( (bomb_x + 40 == block2_x & bomb_y == block2_y) | (bomb_x - 40 == block2_x & bomb_y == block2_y) | 
                                (bomb_x == block2_x & bomb_y + 60 == block2_y) | (bomb_x == block2_x & bomb_y - 60 == block2_y) )
                            begin block2_explode <= 1; end
                        if (  (bomb_x + 40 == block3_x & bomb_y == block3_y) | (bomb_x - 40 == block3_x & bomb_y == block3_y) | 
                                (bomb_x == block3_x & bomb_y + 60 == block3_y) | (bomb_x == block3_x & bomb_y - 60 == block3_y)  )
                            begin block3_explode <= 1; end
                        if ( (bomb_x + 40 == block4_x & bomb_y == block4_y) | (bomb_x - 40 == block4_x & bomb_y == block4_y) | 
                                (bomb_x == block4_x & bomb_y + 60 == block4_y) | (bomb_x == block4_x & bomb_y - 60 == block4_y) )
                            begin block4_explode <= 1; end
     
                        end                
               
                    end // End Move
                Bomb : begin
                          
                        if (button_out[0] == 1'b1) begin // S0 : Right
                            if ( (block2_explode == 0 & person_x + 40 == block2_x & person_y == block2_y) || 
                                 (block3_explode == 0 & person_x + 40 == block3_x & person_y == block3_y) || 
                                 (block4_explode == 0 & person_x + 40 == block4_x & person_y == block4_y) || 
                                 (person_x + 40 == house2_x & person_y == house2_y) || (person_x + 40 == house3_x & person_y == house3_y) || 
                                 (person_x + 40 == tree3_x & person_y == tree3_y) || (person_x + 40 == bomb_x & person_y == bomb_y) || person_x > 10'd246) 
                                begin person_next_x <= person_x; end
                            else begin 
                                person_next_x <= person_x + 10'd40;
                                end
                        end 
                        else if (button_out[3] == 1'b1) begin // S3 : Left
                            if ( (block1_explode == 0 & person_x - 40 == block1_x & person_y == block1_y) || 
                             (block2_explode == 0 & person_x - 40 == block2_x & person_y == block2_y) || 
                             (block4_explode == 0 & person_x - 40 == block4_x & person_y == block4_y) || 
                             (person_x - 40 == house2_x & person_y == house2_y) || 
                             (person_x - 40 == tree1_x & person_y == tree1_y) || (person_x - 40 == tree2_x & person_y == tree2_y) || 
                             (person_x - 40 == tree3_x & person_y == tree3_y) || (person_x - 40 == bomb_x & person_y == bomb_y) || person_x < 10'd46) 
                                begin person_next_x <= person_x; end
                            else begin 
                                person_next_x <= person_x - 10'd40;
                                end
                        end                                      
                        else if (button_out[2] == 1'b1) begin // S2 : Down
                            if ( (block1_explode == 0 & person_y + 60 == block1_y & person_x == block1_x) || 
                                 (block2_explode == 0 & person_y + 60 == block2_y & person_x == block2_x) ||  
                                 (block3_explode == 0 & person_y + 60 == block3_y & person_x == block3_x) || 
                                 (block4_explode == 0 & person_y + 60 == block4_y & person_x == block4_x) ||
                                 (person_y + 60 == house1_y & person_x == house1_x) || (person_y + 60 == house2_y & person_x == house2_x) ||
                                 (person_y + 60 == tree1_y & person_x == tree1_x) || (person_y + 60 == tree2_y & person_x == tree2_x) ||
                                 (person_y + 60 == tree3_y & person_x == tree3_x) || (person_y + 60 == bomb_y & person_x == bomb_x) || person_y > 10'd426) 
                                begin person_next_y <= person_y; end
                            else begin 
                                person_next_y <= person_y + 10'd60;
                                end
                            end 
                        else if (button_out[4] == 1'b1) begin // S4 : Up
                            if ( (block1_explode == 0 & person_y - 60 == block1_y & person_x == block1_x) || 
                                 (block2_explode == 0 & person_y - 60 == block2_y & person_x == block2_x) ||  
                                 (block3_explode == 0 & person_y - 60 == block3_y & person_x == block3_x) || 
                                 (block4_explode == 0 & person_y - 60 == block4_y & person_x == block4_x) ||
                                 (person_y - 60 == house1_y & person_x == house1_x) || (person_y - 60 == house2_y & person_x == house2_x) ||
                                 (person_y - 60 == house3_y & person_x == house3_x) || (person_y - 60 == tree2_y & person_x == tree2_x) || 
                                 (person_y - 60 == bomb_y & person_x == bomb_x) || person_y < 10'd66) 
                                begin person_next_y <= person_y; end
                            else begin 
                                person_next_y <= person_y - 10'd60;
                                end
                            end 
                        else begin person_next_x <= person_x; person_next_y <= person_y; end  
    
                    end // End Bomb
                default : ;
            endcase
       end//關卡一
     /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
       else begin//關卡二
            case(NS)                           
                ///////            
                Move : begin  
                    enkeyboard<=1;   
                    if (button_out[0] == 1'b1) begin // S0 : Right
                        if ( (block_explode[0] == 0 & person_x + 40 == block_x[0] & person_y == block_y[0]) || (block_explode[1] == 0 & person_x + 40 == block_x[1] & person_y == block_y[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_x + 40 == block_x[2] & person_y == block_y[2]) || (block_explode[3] == 0 & person_x + 40 == block_x[3] & person_y == block_y[3]) || 
                             (block_explode[4] == 0 & person_x + 40 == block_x[4] & person_y == block_y[4]) || (block_explode[5] == 0 & person_x + 40 == block_x[5] & person_y == block_y[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_x + 40 == block_x[6] & person_y == block_y[6]) || (block_explode[7] == 0 & person_x + 40 == block_x[7] & person_y == block_y[7]) || 
                             (block_explode[8] == 0 & person_x + 40 == block_x[8] & person_y == block_y[8]) || (block_explode[9] == 0 & person_x + 40 == block_x[9] & person_y == block_y[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_x + 40 == block_x[10] & person_y == block_y[10]) || (block_explode[11] == 0 & person_x + 40 == block_x[11] & person_y == block_y[11]) ||          
                             (person_x + 40 == house_x[0] & person_y == house_y[0]) || (person_x + 40 == house_x [1]& person_y == house_y[1]) ||// house 擋到 
                             (person_x + 40 == house_x[2] & person_y == house_y[2]) || (person_x + 40 == house_x [3]& person_y == house_y[3]) || 
                             (person_x + 40 == house_x[4] & person_y == house_y[4]) || (person_x + 40 == house_x [5]& person_y == house_y[5]) || 
                             (person_x + 40 == house_x[6] & person_y == house_y[6]) || (person_x + 40 == house_x [7]& person_y == house_y[7]) || 
                             (person_x + 40 == house_x[8] & person_y == house_y[8]) || (person_x + 40 == house_x [9]& person_y == house_y[9]) || 
                             (person_x + 40 == tree_x[0] & person_y == tree_y[0]) || (person_x + 40 == tree_x[1] & person_y == tree_y[1]) ||// tree 擋到 
                             (person_x + 40 == tree_x[2] & person_y == tree_y[2]) || (person_x + 40 == tree_x[3] & person_y == tree_y[3]) ||
                             (person_x + 40 == tree_x[4] & person_y == tree_y[4]) || (person_x + 40 == tree_x[5] & person_y == tree_y[5]) ||
                             (person_x + 40 == tree_x[6] & person_y == tree_y[6]) || (person_x + 40 == tree_x[7] & person_y == tree_y[7]) ||                            
                              person_x > 10'd246) 
                        begin person_next_x <= person_x; end
                        else begin person_next_x <= person_x + 10'd40; end

                    end 
                    else if (button_out[3] == 1'b1) begin // S3 : Left
                        if ( (block_explode[0] == 0 & person_x - 40 == block_x[0] & person_y == block_y[0]) || (block_explode[1] == 0 & person_x - 40 == block_x[1] & person_y == block_y[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_x - 40 == block_x[2] & person_y == block_y[2]) || (block_explode[3] == 0 & person_x - 40 == block_x[3] & person_y == block_y[3]) || 
                             (block_explode[4] == 0 & person_x - 40 == block_x[4] & person_y == block_y[4]) || (block_explode[5] == 0 & person_x - 40 == block_x[5] & person_y == block_y[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_x - 40 == block_x[6] & person_y == block_y[6]) || (block_explode[7] == 0 & person_x - 40 == block_x[7] & person_y == block_y[7]) || 
                             (block_explode[8] == 0 & person_x - 40 == block_x[8] & person_y == block_y[8]) || (block_explode[9] == 0 & person_x - 40 == block_x[9] & person_y == block_y[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_x - 40 == block_x[10] & person_y == block_y[10]) || (block_explode[11] == 0 & person_x - 40 == block_x[11] & person_y == block_y[11]) ||                  
                             (person_x - 40 == house_x[0] & person_y == house_y[0]) || (person_x - 40 == house_x[1] & person_y == house_y[1]) || // house 擋到 
                             (person_x - 40 == house_x[2] & person_y == house_y[2]) || (person_x - 40 == house_x[3] & person_y == house_y[3]) ||
                             (person_x - 40 == house_x[4] & person_y == house_y[4]) || (person_x - 40 == house_x[5] & person_y == house_y[5]) ||
                             (person_x - 40 == house_x[6] & person_y == house_y[6]) || (person_x - 40 == house_x[7] & person_y == house_y[7]) ||
                             (person_x - 40 == house_x[8] & person_y == house_y[8]) || (person_x - 40 == house_x[9] & person_y == house_y[9]) ||
                             (person_x - 40 == tree_x[0] & person_y == tree_y[0]) || (person_x - 40 == tree_x[1] & person_y == tree_y[1]) || // tree 擋到 
                             (person_x - 40 == tree_x[2] & person_y == tree_y[2]) || (person_x - 40 == tree_x[3] & person_y == tree_y[3]) ||
                             (person_x - 40 == tree_x[4] & person_y == tree_y[4]) || (person_x - 40 == tree_x[5] & person_y == tree_y[5]) ||
                             (person_x - 40 == tree_x[6] & person_y == tree_y[6]) || (person_x - 40 == tree_x[7] & person_y == tree_y[7]) ||         
                              person_x < 10'd46) 
                            begin person_next_x <= person_x; end
                        else begin person_next_x <= person_x - 10'd40; end
                    end                                      
                    else if (button_out[2] == 1'b1) begin // S2 : Down
                        if ( (block_explode[0] == 0 & person_y + 60 == block_y[0] & person_x == block_x[0]) || (block_explode[1] == 0 & person_y + 60 == block_y[1] & person_x == block_x[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_y + 60 == block_y[2] & person_x == block_x[2]) || (block_explode[3] == 0 & person_y + 60 == block_y[3] & person_x == block_x[3]) || 
                             (block_explode[4] == 0 & person_y + 60 == block_y[4] & person_x == block_x[4]) || (block_explode[5] == 0 & person_y + 60 == block_y[5] & person_x == block_x[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_y + 60 == block_y[6] & person_x == block_x[6]) || (block_explode[7] == 0 & person_y + 60 == block_y[7] & person_x == block_x[7]) || 
                             (block_explode[8] == 0 & person_y + 60 == block_y[8] & person_x == block_x[8]) || (block_explode[9] == 0 & person_y + 60 == block_y[9] & person_x == block_x[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_y + 60 == block_y[10] & person_x == block_x[10]) || (block_explode[11] == 0 & person_y + 60 == block_y[11] & person_x == block_x[11]) ||  
                             (person_y + 60 == house_y[0] & person_x == house_x[0]) || (person_y + 60 == house_y[1] & person_x == house_x[1]) ||// house 擋到 
                             (person_y + 60 == house_y[2] & person_x == house_x[2]) || (person_y + 60 == house_y[3] & person_x == house_x[3]) ||
                             (person_y + 60 == house_y[4] & person_x == house_x[4]) || (person_y + 60 == house_y[5] & person_x == house_x[5]) ||
                             (person_y + 60 == house_y[6] & person_x == house_x[6]) || (person_y + 60 == house_y[7] & person_x == house_x[7]) ||
                             (person_y + 60 == house_y[8] & person_x == house_x[8]) || (person_y + 60 == house_y[9] & person_x == house_x[9]) ||
                             (person_y + 60 == tree_y[0] & person_x == tree_x[0]) || (person_y + 60 == tree_y[1] & person_x == tree_x[1]) ||// tree 擋到 
                             (person_y + 60 == tree_y[2] & person_x == tree_x[2]) || (person_y + 60 == tree_y[3] & person_x == tree_x[3]) ||
                             (person_y + 60 == tree_y[4] & person_x == tree_x[4]) || (person_y + 60 == tree_y[5] & person_x == tree_x[5]) ||
                             (person_y + 60 == tree_y[6] & person_x == tree_x[6]) || (person_y + 60 == tree_y[7] & person_x == tree_x[7]) ||
                              person_y > 10'd366) 
                            begin person_next_y <= person_y; end
                        else begin person_next_y <= person_y + 10'd60; end

                    end
                    else if (button_out[4] == 1'b1) begin // S4 : Up
                        if ( (block_explode[0] == 0 & person_y - 60 == block_y[0] & person_x == block_x[0]) || (block_explode[1] == 0 & person_y - 60 == block_y[1] & person_x == block_x[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_y - 60 == block_y[2] & person_x == block_x[2]) || (block_explode[3] == 0 & person_y - 60 == block_y[3] & person_x == block_x[3]) || 
                             (block_explode[4] == 0 & person_y - 60 == block_y[4] & person_x == block_x[4]) || (block_explode[5] == 0 & person_y - 60 == block_y[5] & person_x == block_x[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_y - 60 == block_y[6] & person_x == block_x[6]) || (block_explode[7] == 0 & person_y - 60 == block_y[7] & person_x == block_x[7]) || 
                             (block_explode[8] == 0 & person_y - 60 == block_y[8] & person_x == block_x[8]) || (block_explode[9] == 0 & person_y - 60 == block_y[9] & person_x == block_x[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_y - 60 == block_y[10] & person_x == block_x[10]) || (block_explode[11] == 0 & person_y - 60 == block_y[11] & person_x == block_x[11]) || 
                             
                            // (Q_explode[1] == 0 & person_y - 60 == Q1_y & person_x == Q1_x) || (Q_explode[2] == 0 & person_y - 60 == Q2_y & person_x == Q2_x) || // Q W E 擋到                        
                             //(W_explode[1] == 0 & person_y - 60 == W1_y & person_x == W1_x) || (W_explode[2] == 0 & person_y - 60 == W2_y & person_x == W2_x) ||
                             //(E_explode[1] == 0 & person_y - 60 == E1_y & person_x == E1_x) || (E_explode[2] == 0 & person_y - 60 == E2_y & person_x == E2_x) ||
                             (person_y - 60 == house_y[0] & person_x == house_x[0]) || (person_y - 60 == house_y[1] & person_x == house_x[1]) ||// house 擋到 
                             (person_y - 60 == house_y[2] & person_x == house_x[2]) || (person_y - 60 == house_y[3] & person_x == house_x[3]) ||
                             (person_y - 60 == house_y[4] & person_x == house_x[4]) || (person_y - 60 == house_y[5] & person_x == house_x[5]) ||
                             (person_y - 60 == house_y[6] & person_x == house_x[6]) || (person_y - 60 == house_y[7] & person_x == house_x[7]) ||
                             (person_y - 60 == house_y[8] & person_x == house_x[8]) || (person_y - 60 == house_y[9] & person_x == house_x[9]) ||
                             (person_y - 60 == tree_y[0] & person_x == tree_x[0]) || (person_y - 60 == tree_y[1] & person_x == tree_x[1]) ||// tree 擋到 
                             (person_y - 60 == tree_y[2] & person_x == tree_x[2]) || (person_y - 60 == tree_y[3] & person_x == tree_x[3]) ||
                             (person_y - 60 == tree_y[4] & person_x == tree_x[4]) || (person_y - 60 == tree_y[5] & person_x == tree_x[5]) ||
                             (person_y - 60 == tree_y[6] & person_x == tree_x[6]) || (person_y - 60 == tree_y[7] & person_x == tree_x[7]) ||
                              person_y < 10'd66) 
                            begin person_next_y <= person_y; end
                        else begin  person_next_y <= person_y - 10'd60; end
                    end 
                    else begin person_next_x <= person_x; person_next_y <= person_y; end  
                    
                    
                     ///// 輔助道具 /////
                    if( stronger == 0 & person_next_x == help_x & person_next_y == help_y) begin stronger<=2'b10; s<=1'b1; end                  
                    else if( stronger == 2'b10 & NS == Bomb ) begin stronger <= stronger; s<=1; end  
                    else if( stronger == 2'b10 & NS == Move ) begin stronger<=2'b01; s<=s; end         
                    else if( stronger == 1 & state == Bomb ) begin stronger <= 2'b0; s<=s; end
                    else if( stronger == 1 & state == Move ) begin stronger <= stronger; s<=s; end        
                    else begin stronger <= stronger; s<=s; end

                    
                    ///// bomb F /////
                    if (bombF_time == 2) begin bombF_x <= person_x; bombF_y <= person_y; end   
                    else if (bombF_time == 0) begin
                        for(hh=0; hh<=11; hh=hh+1)begin
                            if (stronger == 0 & (  (bombF_x + 40 == block_x[hh] & bombF_y == block_y[hh]) | (bombF_x - 40 == block_x[hh] & bombF_y == block_y[hh]) | 
                                    (bombF_x == block_x[hh] & bombF_y + 60 == block_y[hh] ) | (bombF_x == block_x[hh] & bombF_y - 60 == block_y[hh]) ) )
                                begin block_explode[hh] <= 1; end 
                            else if ( stronger == 1 & ((bombF_y == block_y[hh]) |// 橫軸整個炸掉
                                (bombF_x == block_x[hh] & bombF_y + 60 == block_y[hh] ) | (bombF_x == block_x[hh] & bombF_y - 60 == block_y[hh])))//縱軸威力不變
                                begin block_explode[hh] <= 1; end
                        end//for     
                    end 
                    else begin 
                        for(hh=0; hh<=11; hh=hh+1) begin
                             block_explode[hh] <= block_explode[hh];
                            end        
                    end   
                    
                    ///// bomb Q /////
                    if (bombQ_time == 3) begin bombQ_x <= person_x; bombQ_y <= person_y; end   
                    else if (bombQ_time == 0) begin
                        if ( stronger == 0 & ( (bombQ_x + 40 == Q1_x & bombQ_y == Q1_y) | (bombQ_x - 40 == Q1_x & bombQ_y == Q1_y) | 
                             (bombQ_x == Q1_x & bombQ_y + 60 == Q1_y ) | (bombQ_x == Q1_x & bombQ_y - 60 == Q1_y) ) )
                            begin Q_explode[1] <= 1; end 
                        else if ( stronger == 1 & ((bombQ_y == Q1_y) |// 橫軸整個炸掉
                                (bombQ_x == Q1_x & bombQ_y + 60 == Q1_y ) | (bombQ_x == Q1_x & bombQ_y - 60 == Q1_y)))//縱軸威力不變
                                begin Q_explode[1] <= 1; end 
                                               
                        if ( stronger == 0 & ( (bombQ_x + 40 == Q2_x & bombQ_y == Q2_y) | (bombQ_x - 40 == Q2_x & bombQ_y == Q2_y) | 
                             (bombQ_x == Q2_x & bombQ_y + 60 == Q2_y ) | (bombQ_x == Q2_x & bombQ_y - 60 == Q2_y)) )
                            begin Q_explode[2] <= 1; end    
                        else if(stronger == 1 & ((bombQ_y == Q2_y) |// 橫軸整個炸掉
                                (bombQ_x == Q2_x & bombQ_y + 60 == Q2_y ) | (bombQ_x == Q2_x & bombQ_y - 60 == Q2_y)))//縱軸威力不變
                                begin Q_explode[2] <= 1; end                 
                    end  
                    else begin 
                         Q_explode[1] <= Q_explode[1];
                         Q_explode[2] <= Q_explode[2];       
                    end
                    
                    ///// bomb W/////
                    if (bombW_time == 4) begin bombW_x <= person_x; bombW_y <= person_y; end   
                    else if (bombW_time == 0) begin
                        if ( stronger == 0 & ( (bombW_x + 40 == W1_x & bombW_y == W1_y) | (bombW_x == W1_x & bombW_y + 60 == W1_y ) |
                             (bombW_x - 40 == W1_x & bombW_y == W1_y) | (bombW_x == W1_x & bombW_y - 60 == W1_y) ) )       
                            begin W_explode[1] <= 1; end 
                         else if ( stronger == 1 & ((bombW_y == W1_y) |// 橫軸整個炸掉
                                (bombW_x == W1_x & bombW_y + 60 == W1_y ) | (bombW_x == W1_x & bombW_y - 60 == W1_y)))//縱軸威力不變
                                begin W_explode[1] <= 1; end    
                            
                        if (stronger == 0 & ( (bombW_x + 40 == W2_x & bombW_y == W2_y) | (bombW_x == W2_x & bombW_y + 60 == W2_y ) |
                             (bombW_x - 40 == W2_x & bombW_y == W2_y) | (bombW_x == W2_x & bombW_y - 60 == W2_y) ) )       
                            begin W_explode[2] <= 1; end  
                        else if ( stronger == 1 & ((bombW_y == W2_y) |// 橫軸整個炸掉
                                (bombW_x == W2_x & bombW_y + 60 == W2_y ) | (bombW_x == W2_x & bombW_y - 60 == W2_y)))//縱軸威力不變
                                begin W_explode[2] <= 1; end 
                                                 
                    end 
                    else begin 
                         W_explode[1] <= W_explode[1];
                         W_explode[2] <= W_explode[2];       
                    end
                    
                    ///// bomb E /////
                    if (bombE_time == 5) begin bombE_x <= person_x; bombE_y <= person_y; end
                    else if (bombE_time == 0) begin
                        if ( stronger == 0 & ( (bombE_x + 40 == E1_x & bombE_y == E1_y) | (bombE_x == E1_x & bombE_y + 60 == E1_y ) |
                             (bombE_x - 40 == E1_x & bombE_y == E1_y) | (bombE_x == E1_x & bombE_y - 60 == E1_y) ) )       
                            begin E_explode[1] <= 1; end 
                        else if ( stronger == 1 & ((bombE_y == E1_y) |// 橫軸整個炸掉
                                (bombE_x == E1_x & bombE_y + 60 == E1_y ) | (bombE_x == E1_x & bombE_y - 60 == E1_y)))//縱軸威力不變
                                begin E_explode[1] <= 1; end
                            
                        if ( stronger == 0 & ( (bombE_x + 40 == E2_x & bombE_y == E2_y) | (bombE_x == E2_x & bombE_y + 60 == E2_y ) |
                             (bombE_x - 40 == E2_x & bombE_y == E2_y) | (bombE_x == E2_x & bombE_y - 60 == E2_y) ) )       
                            begin E_explode[2] <= 1; end
                        else if ( stronger == 1 & ((bombE_y == E2_y) |// 橫軸整個炸掉
                                (bombE_x == E2_x & bombE_y + 60 == E2_y ) | (bombE_x == E2_x & bombE_y - 60 == E2_y)))//縱軸威力不變
                                begin E_explode[2] <= 1; end     
                    end 
                    else begin 
                         E_explode[1] <= E_explode[1];
                         E_explode[2] <= E_explode[2];       
                    end 
                end // End Move
                
                Bomb : begin
                    enkeyboard<=0;   
                    if (button_out[0] == 1'b1) begin // S0 : Right
                        if ( (block_explode[0] == 0 & person_x + 40 == block_x[0] & person_y == block_y[0]) || (block_explode[1] == 0 & person_x + 40 == block_x[1] & person_y == block_y[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_x + 40 == block_x[2] & person_y == block_y[2]) || (block_explode[3] == 0 & person_x + 40 == block_x[3] & person_y == block_y[3]) || 
                             (block_explode[4] == 0 & person_x + 40 == block_x[4] & person_y == block_y[4]) || (block_explode[5] == 0 & person_x + 40 == block_x[5] & person_y == block_y[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_x + 40 == block_x[6] & person_y == block_y[6]) || (block_explode[7] == 0 & person_x + 40 == block_x[7] & person_y == block_y[7]) || 
                             (block_explode[8] == 0 & person_x + 40 == block_x[8] & person_y == block_y[8]) || (block_explode[9] == 0 & person_x + 40 == block_x[9] & person_y == block_y[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_x + 40 == block_x[10] & person_y == block_y[10]) || (block_explode[11] == 0 & person_x + 40 == block_x[11] & person_y == block_y[11]) || 
                             (person_x + 40 == house_x[0] & person_y == house_y[0]) || (person_x + 40 == house_x [1]& person_y == house_y[1]) ||// house 擋到 
                             (person_x + 40 == house_x[2] & person_y == house_y[2]) || (person_x + 40 == house_x [3]& person_y == house_y[3]) || 
                             (person_x + 40 == house_x[4] & person_y == house_y[4]) || (person_x + 40 == house_x [5]& person_y == house_y[5]) || 
                             (person_x + 40 == house_x[6] & person_y == house_y[6]) || (person_x + 40 == house_x [7]& person_y == house_y[7]) || 
                             (person_x + 40 == house_x[8] & person_y == house_y[8]) || (person_x + 40 == house_x [9]& person_y == house_y[9]) || 
                             (person_x + 40 == tree_x[0] & person_y == tree_y[0]) || (person_x + 40 == tree_x[1] & person_y == tree_y[1]) ||// tree 擋到 
                             (person_x + 40 == tree_x[2] & person_y == tree_y[2]) || (person_x + 40 == tree_x[3] & person_y == tree_y[3]) ||
                             (person_x + 40 == tree_x[4] & person_y == tree_y[4]) || (person_x + 40 == tree_x[5] & person_y == tree_y[5]) ||
                             (person_x + 40 == tree_x[6] & person_y == tree_y[6]) || (person_x + 40 == tree_x[7] & person_y == tree_y[7]) ||                            
                             (person_x + 40 == bombF_x & person_y == bombF_y) || (person_x + 40 == bombQ_x & person_y == bombQ_y) ||
                             (person_x + 40 == bombE_x & person_y == bombE_y) || (person_x + 40 == bombW_x & person_y == bombW_y) || person_x > 10'd246) 
                             begin person_next_x <= person_x; end
                        else begin person_next_x <= person_x + 10'd40; end
                end 
                    else if (button_out[3] == 1'b1) begin // S3 : Left
                        if ( (block_explode[0] == 0 & person_x - 40 == block_x[0] & person_y == block_y[0]) || (block_explode[1] == 0 & person_x - 40 == block_x[1] & person_y == block_y[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_x - 40 == block_x[2] & person_y == block_y[2]) || (block_explode[3] == 0 & person_x - 40 == block_x[3] & person_y == block_y[3]) || 
                             (block_explode[4] == 0 & person_x - 40 == block_x[4] & person_y == block_y[4]) || (block_explode[5] == 0 & person_x - 40 == block_x[5] & person_y == block_y[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_x - 40 == block_x[6] & person_y == block_y[6]) || (block_explode[7] == 0 & person_x - 40 == block_x[7] & person_y == block_y[7]) || 
                             (block_explode[8] == 0 & person_x - 40 == block_x[8] & person_y == block_y[8]) || (block_explode[9] == 0 & person_x - 40 == block_x[9] & person_y == block_y[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_x - 40 == block_x[10] & person_y == block_y[10]) || (block_explode[11] == 0 & person_x - 40 == block_x[11] & person_y == block_y[11]) || 
                             (person_x - 40 == house_x[0] & person_y == house_y[0]) || (person_x - 40 == house_x[1] & person_y == house_y[1]) || // house 擋到 
                             (person_x - 40 == house_x[2] & person_y == house_y[2]) || (person_x - 40 == house_x[3] & person_y == house_y[3]) ||
                             (person_x - 40 == house_x[4] & person_y == house_y[4]) || (person_x - 40 == house_x[5] & person_y == house_y[5]) ||
                             (person_x - 40 == house_x[6] & person_y == house_y[6]) || (person_x - 40 == house_x[7] & person_y == house_y[7]) ||
                             (person_x - 40 == house_x[8] & person_y == house_y[8]) || (person_x - 40 == house_x[9] & person_y == house_y[9]) ||
                             (person_x - 40 == tree_x[0] & person_y == tree_y[0]) || (person_x - 40 == tree_x[1] & person_y == tree_y[1]) || // tree 擋到 
                             (person_x - 40 == tree_x[2] & person_y == tree_y[2]) || (person_x - 40 == tree_x[3] & person_y == tree_y[3]) ||
                             (person_x - 40 == tree_x[4] & person_y == tree_y[4]) || (person_x - 40 == tree_x[5] & person_y == tree_y[5]) ||
                             (person_x - 40 == tree_x[6] & person_y == tree_y[6]) || (person_x - 40 == tree_x[7] & person_y == tree_y[7]) ||         
                             (person_x - 40 == bombF_x & person_y == bombF_y) || (person_x - 40 == bombQ_x & person_y == bombQ_y) ||
                             (person_x - 40 == bombE_x & person_y == bombE_y) || (person_x - 40 == bombW_x & person_y == bombW_y) || person_x < 10'd46) 
                             begin person_next_x <= person_x; end
                        else begin person_next_x <= person_x - 10'd40; end
                    end                                      
                    else if (button_out[2] == 1'b1) begin // S2 : Down
                        if ( (block_explode[0] == 0 & person_y + 60 == block_y[0] & person_x == block_x[0]) || (block_explode[1] == 0 & person_y + 60 == block_y[1] & person_x == block_x[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_y + 60 == block_y[2] & person_x == block_x[2]) || (block_explode[3] == 0 & person_y + 60 == block_y[3] & person_x == block_x[3]) || 
                             (block_explode[4] == 0 & person_y + 60 == block_y[4] & person_x == block_x[4]) || (block_explode[5] == 0 & person_y + 60 == block_y[5] & person_x == block_x[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_y + 60 == block_y[6] & person_x == block_x[6]) || (block_explode[7] == 0 & person_y + 60 == block_y[7] & person_x == block_x[7]) || 
                             (block_explode[8] == 0 & person_y + 60 == block_y[8] & person_x == block_x[8]) || (block_explode[9] == 0 & person_y + 60 == block_y[9] & person_x == block_x[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_y + 60 == block_y[10] & person_x == block_x[10]) || (block_explode[11] == 0 & person_y + 60 == block_y[11] & person_x == block_x[11]) || 
                             (person_y + 60 == house_y[0] & person_x == house_x[0]) || (person_y + 60 == house_y[1] & person_x == house_x[1]) ||// house 擋到 
                             (person_y + 60 == house_y[2] & person_x == house_x[2]) || (person_y + 60 == house_y[3] & person_x == house_x[3]) ||
                             (person_y + 60 == house_y[4] & person_x == house_x[4]) || (person_y + 60 == house_y[5] & person_x == house_x[5]) ||
                             (person_y + 60 == house_y[6] & person_x == house_x[6]) || (person_y + 60 == house_y[7] & person_x == house_x[7]) ||
                             (person_y + 60 == house_y[8] & person_x == house_x[8]) || (person_y + 60 == house_y[9] & person_x == house_x[9]) ||
                             (person_y + 60 == tree_y[0] & person_x == tree_x[0]) || (person_y + 60 == tree_y[1] & person_x == tree_x[1]) ||// tree 擋到 
                             (person_y + 60 == tree_y[2] & person_x == tree_x[2]) || (person_y + 60 == tree_y[3] & person_x == tree_x[3]) ||
                             (person_y + 60 == tree_y[4] & person_x == tree_x[4]) || (person_y + 60 == tree_y[5] & person_x == tree_x[5]) ||
                             (person_y + 60 == tree_y[6] & person_x == tree_x[6]) || (person_y + 60 == tree_y[7] & person_x == tree_x[7]) ||
                             (person_y + 60 == bombF_y & person_x == bombF_x) || (person_y + 60 == bombW_y & person_x == bombW_x) ||
                             (person_y + 60 == bombQ_y & person_x == bombQ_x) || (person_y + 60 == bombE_y & person_x == bombE_x) || person_y > 10'd366) 
                             begin person_next_y <= person_y; end
                        else begin person_next_y <= person_y + 10'd60; end
                    end
                    else if (button_out[4] == 1'b1) begin // S4 : Up
                        if ( (block_explode[0] == 0 & person_y - 60 == block_y[0] & person_x == block_x[0]) || (block_explode[1] == 0 & person_y - 60 == block_y[1] & person_x == block_x[1]) ||  // block 擋到    
                             (block_explode[2] == 0 & person_y - 60 == block_y[2] & person_x == block_x[2]) || (block_explode[3] == 0 & person_y - 60 == block_y[3] & person_x == block_x[3]) || 
                             (block_explode[4] == 0 & person_y - 60 == block_y[4] & person_x == block_x[4]) || (block_explode[5] == 0 & person_y - 60 == block_y[5] & person_x == block_x[5]) ||  // block 擋到    
                             (block_explode[6] == 0 & person_y - 60 == block_y[6] & person_x == block_x[6]) || (block_explode[7] == 0 & person_y - 60 == block_y[7] & person_x == block_x[7]) || 
                             (block_explode[8] == 0 & person_y - 60 == block_y[8] & person_x == block_x[8]) || (block_explode[9] == 0 & person_y - 60 == block_y[9] & person_x == block_x[9]) ||  // block 擋到    
                             (block_explode[10] == 0 & person_y - 60 == block_y[10] & person_x == block_x[10]) || (block_explode[11] == 0 & person_y - 60 == block_y[11] & person_x == block_x[11]) || 
                             (person_y - 60 == house_y[0] & person_x == house_x[0]) || (person_y - 60 == house_y[1] & person_x == house_x[1]) ||// house 擋到 
                             (person_y - 60 == house_y[2] & person_x == house_x[2]) || (person_y - 60 == house_y[3] & person_x == house_x[3]) ||
                             (person_y - 60 == house_y[4] & person_x == house_x[4]) || (person_y - 60 == house_y[5] & person_x == house_x[5]) ||
                             (person_y - 60 == house_y[6] & person_x == house_x[6]) || (person_y - 60 == house_y[7] & person_x == house_x[7]) ||
                             (person_y - 60 == house_y[8] & person_x == house_x[8]) || (person_y - 60 == house_y[9] & person_x == house_x[9]) ||
                             (person_y - 60 == tree_y[0] & person_x == tree_x[0]) || (person_y - 60 == tree_y[1] & person_x == tree_x[1]) ||// tree 擋到 
                             (person_y - 60 == tree_y[2] & person_x == tree_x[2]) || (person_y - 60 == tree_y[3] & person_x == tree_x[3]) ||
                             (person_y - 60 == tree_y[4] & person_x == tree_x[4]) || (person_y - 60 == tree_y[5] & person_x == tree_x[5]) ||
                             (person_y - 60 == tree_y[6] & person_x == tree_x[6]) || (person_y - 60 == tree_y[7] & person_x == tree_x[7]) ||
                             (person_y - 60 == bombF_y & person_x == bombF_x) || (person_y - 60 == bombW_y & person_x == bombW_x) ||
                             (person_y - 60 == bombQ_y & person_x == bombQ_x) || (person_y - 60 == bombE_y & person_x == bombE_x) || person_y < 10'd66) 
                            begin person_next_y <= person_y; end
                        else begin  person_next_y <= person_y - 10'd60; end
                    end 
                    else begin person_next_x <= person_x; person_next_y <= person_y; end    
    
                    end // End Bomb
    
    
                default : ;
            endcase
       
       end                                          
       end // End rst == 0                                 
end // end process SEQ       

     ////////// Poison Move //////////                                                                         
     reg RF;  //  1：向右      0：向左                                                                                  
     always@(posedge clk2, negedge rst)                                                                      
     begin
        if (!rst) begin poison_next_x <= 10'd286; poison_x <= 10'd286; poison_y<=10'd306; RF<=0; end
        else begin                                                                                                                                                                                                
            // if(state==Die ||state==Win) poison_x <= poison_x;                                               
             if ( NS== Move | NS==Bomb ) begin
                if ( RF==0 ) begin                                                            
                    if ( poison_x == 6 ) begin 
                        poison_next_x <= 10'd46; poison_x <= 10'd46; RF<=1;  end                           
                    else begin  
                        poison_next_x <= poison_x - 10'd40; poison_x <= poison_x - 10'd40; end 
                    end                   
                else begin                                                                                               
                    if ( poison_x == 286 ) begin 
                        poison_next_x <= 10'd246; poison_x <= 10'd246;RF<=0;  end                         
                    else begin 
                        poison_next_x <= poison_x + 10'd40; poison_x <= poison_x + 10'd40; end 
                    end        
             end                                                                                               
             else poison_next_x <= poison_x;
         end                                                                                                                                                                       
     end 
    
    reg Q1_right, Q2_right, W1_right, W2_right, E1_right, E2_right;
    reg Q1_wrong, Q2_wrong, W1_wrong, W2_wrong, E1_wrong, E2_wrong;
    always@(posedge clk3, negedge rst)
    begin
        if(!rst) begin 
            Q1_right<=0; Q2_right<=0; W1_right<=0; W2_right<=0; E1_right<=0; E2_right<=0;
            Q1_wrong<=0; Q2_wrong<=0; W1_wrong<=0; W2_wrong<=0; E1_wrong<=0; E2_wrong<=0;
        end
        else begin
                    ///// bomb F /////
                    if (bombF_time == 1) begin 
                        if ( Q_explode[1]==0 & stronger != 1  & 
                            (bombF_x + 40 == Q1_x & bombF_y == Q1_y) | (bombF_x == Q1_x & bombF_y + 60 == Q1_y ) |  (bombF_x - 40 == Q1_x & bombF_y == Q1_y) | (bombF_x == Q1_x & bombF_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[1]==0 & stronger == 1 & 
                                 (bombF_y == Q1_y) | (bombF_x == Q1_x & bombF_y + 60 == Q1_y ) | (bombF_x == Q1_x & bombF_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else Q1_wrong<=0;
                         
                        if ( Q_explode[2]==0 & stronger != 1  &  
                            (bombF_x + 40 == Q2_x & bombF_y == Q2_y) | (bombF_x == Q2_x & bombF_y + 60 == Q2_y ) | (bombF_x - 40 == Q2_x & bombF_y == Q2_y) | (bombF_x == Q2_x & bombF_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombF_y == Q2_y) | (bombF_x == Q2_x & bombF_y + 60 == Q2_y ) | (bombF_x == Q2_x & bombF_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的                            
                        else Q2_wrong<=0;
                        
                        if ( W_explode[1]==0 & stronger != 1  &  
                            (bombF_x + 40 == W1_x & bombF_y == W1_y) | (bombF_x == W1_x & bombF_y + 60 == W1_y ) | (bombF_x - 40 == W1_x & bombF_y == W1_y) | (bombF_x == W1_x & bombF_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombF_y == W1_y) | (bombF_x == W1_x & bombF_y + 60 == W1_y ) | (bombF_x == W1_x & bombF_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的                            
                        else W1_wrong<=0;
                         
                        if ( W_explode[2]==0 & stronger != 1  &  
                            (bombF_x + 40 == W2_x & bombF_y == W2_y) | (bombF_x == W2_x & bombF_y + 60 == W2_y ) | (bombF_x - 40 == W2_x & bombF_y == W2_y) | (bombF_x == W2_x & bombF_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombF_y == W2_y) | (bombF_x == W2_x & bombF_y + 60 == W2_y ) | (bombF_x == W2_x & bombF_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的                            
                        else W2_wrong<=0;
                        
                        if ( E_explode[1]==0 & stronger != 1  &  
                            (bombF_x + 40 == E1_x & bombF_y == E1_y) | (bombF_x == E1_x & bombF_y + 60 == E1_y ) | (bombF_x - 40 == E1_x & bombF_y == E1_y) | (bombF_x == E1_x & bombF_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombF_y == E1_y) | (bombF_x == E1_x & bombF_y + 60 == E1_y ) | (bombF_x == E1_x & bombF_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的                            
                        else E1_wrong<=0;
                         
                        if ( E_explode[2]==0 & stronger != 1  &  
                            (bombF_x + 40 == E2_x & bombF_y == E2_y) | (bombF_x == E2_x & bombF_y + 60 == E2_y ) | (bombF_x - 40 == E2_x & bombF_y == E2_y) | (bombF_x == E2_x & bombF_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombF_y == E2_y) | (bombF_x == E2_x & bombF_y + 60 == E2_y ) | (bombF_x == E2_x & bombF_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的                            
                        else E2_wrong<=0;        
                    end   
   
                    
                    ///// bomb Q /////
                    else if (bombQ_time == 1) begin 
                        if ( Q_explode[1]==0 & stronger != 1  & 
                            (bombQ_x + 40 == Q1_x & bombQ_y == Q1_y) | (bombQ_x == Q1_x & bombQ_y + 60 == Q1_y ) |  (bombQ_x - 40 == Q1_x & bombQ_y == Q1_y) | (bombQ_x == Q1_x & bombQ_y - 60 == Q1_y) )
                            begin Q1_right<=1; end  //炸到對的
                        else if ( Q_explode[1]==0 & stronger == 1 & 
                                 (bombQ_y == Q1_y) | (bombQ_x == Q1_x & bombQ_y + 60 == Q1_y ) | (bombQ_x == Q1_x & bombQ_y - 60 == Q1_y) )
                            begin Q1_right<=1; end  //炸到對的
                        else Q1_right=0;
                         
                        if ( Q_explode[2]==0 & stronger != 1  &  
                            (bombQ_x + 40 == Q2_x & bombQ_y == Q2_y) | (bombQ_x == Q2_x & bombQ_y + 60 == Q2_y ) | (bombQ_x - 40 == Q2_x & bombQ_y == Q2_y) | (bombQ_x == Q2_x & bombQ_y - 60 == Q2_y) )
                            begin Q2_right<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombQ_y == Q2_y) | (bombQ_x == Q2_x & bombQ_y + 60 == Q2_y ) | (bombQ_x == Q2_x & bombQ_y - 60 == Q2_y) )
                            begin Q2_right<=1; end  //炸到錯的                            
                        else Q2_right<=0;
                        
                        if ( W_explode[1]==0 & stronger != 1  &  
                            (bombQ_x + 40 == W1_x & bombQ_y == W1_y) | (bombQ_x == W1_x & bombQ_y + 60 == W1_y ) | (bombQ_x - 40 == W1_x & bombQ_y == W1_y) | (bombQ_x == W1_x & bombQ_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombQ_y == W1_y) | (bombQ_x == W1_x & bombQ_y + 60 == W1_y ) | (bombQ_x == W1_x & bombQ_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的                            
                        else W1_wrong<=0;
                         
                        if ( W_explode[2]==0 & stronger != 1  &  
                            (bombQ_x + 40 == W2_x & bombQ_y == W2_y) | (bombQ_x == W2_x & bombQ_y + 60 == W2_y ) | (bombQ_x - 40 == W2_x & bombQ_y == W2_y) | (bombQ_x == W2_x & bombQ_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombQ_y == W2_y) | (bombQ_x == W2_x & bombQ_y + 60 == W2_y ) | (bombQ_x == W2_x & bombQ_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的                            
                        else W2_wrong<=0;
                        
                        if ( E_explode[1]==0 & stronger != 1  &  
                            (bombQ_x + 40 == E1_x & bombQ_y == E1_y) | (bombQ_x == E1_x & bombQ_y + 60 == E1_y ) | (bombQ_x - 40 == E1_x & bombQ_y == E1_y) | (bombQ_x == E1_x & bombQ_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombQ_y == E1_y) | (bombQ_x == E1_x & bombQ_y + 60 == E1_y ) | (bombQ_x == E1_x & bombQ_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的                            
                        else E1_wrong<=0;
                         
                        if ( E_explode[2]==0 & stronger != 1  &  
                            (bombQ_x + 40 == E2_x & bombQ_y == E2_y) | (bombQ_x == E2_x & bombQ_y + 60 == E2_y ) | (bombQ_x - 40 == E2_x & bombQ_y == E2_y) | (bombQ_x == E2_x & bombQ_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombQ_y == E2_y) | (bombQ_x == E2_x & bombQ_y + 60 == E2_y ) | (bombQ_x == E2_x & bombQ_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的                            
                        else E2_wrong<=0;        
                    end
                    
                    ///// bomb W/////
                    else if (bombW_time == 1) begin 
                        if ( Q_explode[1]==0 & stronger != 1  & 
                            (bombW_x + 40 == Q1_x & bombW_y == Q1_y) | (bombW_x == Q1_x & bombW_y + 60 == Q1_y ) |  (bombW_x - 40 == Q1_x & bombW_y == Q1_y) | (bombW_x == Q1_x & bombW_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[1]==0 & stronger == 1 & 
                                 (bombW_y == Q1_y) | (bombW_x == Q1_x & bombW_y + 60 == Q1_y ) | (bombW_x == Q1_x & bombW_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else Q1_wrong<=0;
                         
                        if ( Q_explode[2]==0 & stronger != 1  &  
                            (bombW_x + 40 == Q2_x & bombW_y == Q2_y) | (bombW_x == Q2_x & bombW_y + 60 == Q2_y ) | (bombW_x - 40 == Q2_x & bombW_y == Q2_y) | (bombW_x == Q2_x & bombW_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombW_y == Q2_y) | (bombW_x == Q2_x & bombW_y + 60 == Q2_y ) | (bombW_x == Q2_x & bombW_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的                            
                        else Q2_wrong<=0;
                        
                        if ( W_explode[1]==0 & stronger != 1  &  
                            (bombW_x + 40 == W1_x & bombW_y == W1_y) | (bombW_x == W1_x & bombW_y + 60 == W1_y ) | (bombW_x - 40 == W1_x & bombW_y == W1_y) | (bombW_x == W1_x & bombW_y - 60 == W1_y) )
                            begin W1_right<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombW_y == W1_y) | (bombW_x == W1_x & bombW_y + 60 == W1_y ) | (bombW_x == W1_x & bombW_y - 60 == W1_y) )
                            begin W1_right<=1; end  //炸到錯的                            
                        else W1_right<=0;
                         
                        if ( W_explode[2]==0 & stronger != 1  &  
                            (bombW_x + 40 == W2_x & bombW_y == W2_y) | (bombW_x == W2_x & bombW_y + 60 == W2_y ) | (bombW_x - 40 == W2_x & bombW_y == W2_y) | (bombW_x == W2_x & bombW_y - 60 == W2_y) )
                            begin W2_right<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombW_y == W2_y) | (bombW_x == W2_x & bombW_y + 60 == W2_y ) | (bombW_x == W2_x & bombW_y - 60 == W2_y) )
                            begin W2_right<=1; end  //炸到錯的                            
                        else W2_right<=0;
                        
                        if ( E_explode[1]==0 & stronger != 1  &  
                            (bombW_x + 40 == E1_x & bombW_y == E1_y) | (bombW_x == E1_x & bombW_y + 60 == E1_y ) | (bombW_x - 40 == E1_x & bombW_y == E1_y) | (bombW_x == E1_x & bombW_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombW_y == E1_y) | (bombW_x == E1_x & bombW_y + 60 == E1_y ) | (bombW_x == E1_x & bombW_y - 60 == E1_y) )
                            begin E1_wrong<=1; end  //炸到錯的                            
                        else E1_wrong<=0;
                         
                        if ( E_explode[2]==0 & stronger != 1  &  
                            (bombW_x + 40 == E2_x & bombW_y == E2_y) | (bombW_x == E2_x & bombW_y + 60 == E2_y ) | (bombW_x - 40 == E2_x & bombW_y == E2_y) | (bombW_x == E2_x & bombW_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombW_y == E2_y) | (bombW_x == E2_x & bombW_y + 60 == E2_y ) | (bombW_x == E2_x & bombW_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的                            
                        else E2_wrong<=0;        
                    end
                    
                    ///// bomb E /////
                    else if (bombE_time == 1) begin 
                        if ( Q_explode[1]==0 & stronger != 1  & 
                            (bombE_x + 40 == Q1_x & bombE_y == Q1_y) | (bombE_x == Q1_x & bombE_y + 60 == Q1_y ) |  (bombE_x - 40 == Q1_x & bombE_y == Q1_y) | (bombE_x == Q1_x & bombE_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[1]==0 & stronger == 1 & 
                                 (bombE_y == Q1_y) | (bombE_x == Q1_x & bombE_y + 60 == Q1_y ) | (bombE_x == Q1_x & bombE_y - 60 == Q1_y) )
                            begin Q1_wrong<=1; end  //炸到錯的
                        else Q1_wrong<=0;
                         
                        if ( Q_explode[2]==0 & stronger != 1  &  
                            (bombE_x + 40 == Q2_x & bombE_y == Q2_y) | (bombE_x == Q2_x & bombE_y + 60 == Q2_y ) | (bombE_x - 40 == Q2_x & bombE_y == Q2_y) | (bombE_x == Q2_x & bombE_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombE_y == Q2_y) | (bombE_x == Q2_x & bombE_y + 60 == Q2_y ) | (bombE_x == Q2_x & bombE_y - 60 == Q2_y) )
                            begin Q2_wrong<=1; end  //炸到錯的                            
                        else Q2_wrong<=0;
                        
                        if ( W_explode[1]==0 & stronger != 1  &  
                            (bombE_x + 40 == W1_x & bombE_y == W1_y) | (bombE_x == W1_x & bombE_y + 60 == W1_y ) | (bombE_x - 40 == W1_x & bombE_y == W1_y) | (bombE_x == W1_x & bombE_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombE_y == W1_y) | (bombE_x == W1_x & bombE_y + 60 == W1_y ) | (bombE_x == W1_x & bombE_y - 60 == W1_y) )
                            begin W1_wrong<=1; end  //炸到錯的                            
                        else W1_wrong<=0;
                         
                        if ( W_explode[2]==0 & stronger != 1  &  
                            (bombE_x + 40 == W2_x & bombE_y == W2_y) | (bombE_x == W2_x & bombE_y + 60 == W2_y ) | (bombE_x - 40 == W2_x & bombE_y == W2_y) | (bombE_x == W2_x & bombE_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombE_y == W2_y) | (bombE_x == W2_x & bombE_y + 60 == W2_y ) | (bombE_x == W2_x & bombE_y - 60 == W2_y) )
                            begin W2_wrong<=1; end  //炸到錯的                            
                        else W2_wrong<=0;
                        
                        if ( E_explode[1]==0 & stronger != 1  &  
                            (bombE_x + 40 == E1_x & bombE_y == E1_y) | (bombE_x == E1_x & bombE_y + 60 == E1_y ) | (bombE_x - 40 == E1_x & bombE_y == E1_y) | (bombE_x == E1_x & bombE_y - 60 == E1_y) )
                            begin E1_right<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombE_y == E1_y) | (bombE_x == E1_x & bombE_y + 60 == E1_y ) | (bombE_x == E1_x & bombE_y - 60 == E1_y) )
                            begin E1_right<=1; end  //炸到錯的                            
                        else E1_right<=0;
                         
                        if ( E_explode[2]==0 & stronger != 1  &  
                            (bombE_x + 40 == E2_x & bombE_y == E2_y) | (bombE_x == E2_x & bombE_y + 60 == E2_y ) | (bombE_x - 40 == E2_x & bombE_y == E2_y) | (bombE_x == E2_x & bombE_y - 60 == E2_y) )
                            begin E2_right<=1; end  //炸到錯的
                        else if ( Q_explode[2]==0 & stronger == 1 & 
                                 (bombE_y == E2_y) | (bombE_x == E2_x & bombE_y + 60 == E2_y ) | (bombE_x == E2_x & bombE_y - 60 == E2_y) )
                            begin E2_wrong<=1; end  //炸到錯的                            
                        else E2_right<=0;        
                    end
                    else begin
                        Q1_right<=0; Q2_right<=0; W1_right<=0; W2_right<=0; E1_right<=0; E2_right<=0;
                        Q1_wrong<=0; Q2_wrong<=0; W1_wrong<=0; W2_wrong<=0; E1_wrong<=0; E2_wrong<=0; 
                        end       
            end
        end


    
   /////////// 倒數計時 //////////  第一關
   always@(posedge clk3, negedge rst)
   begin
       if(!rst) begin times<=5'd30; times2<=8'd60; end
       else begin 
       /////////// 倒數計時 //////////  第一關
        if (Switch == 0) begin
            if( NS==Win || NS==Die || NS==Stop) times<=times; 
            else begin
                times<=times-5'd1;
            end
        end
        /////////// 倒數計時 //////////  第二關
        else begin  
            if( NS==Win || NS==Die || NS==Stop) times2<=times2; 
            else begin
                if (Q1_wrong==1 | Q2_wrong==1 | W1_wrong==1 | W2_wrong==1 | E1_wrong==1 | E2_wrong==1 |
                    Q1_right==1 | Q2_right==1 | W1_right==1 | W2_right==1 | E1_right==1 | E2_right==1 )
                    times2 <= times2-5*(Q1_wrong+Q2_wrong+W1_wrong+W2_wrong+E1_wrong+E2_wrong)
                                      +3*(Q1_right+Q2_right+W1_right+W2_right+E1_right+E2_right);
               else times2 <= times2-1;
//                times2<=times2-6'd1;
                
            end
    
       end // Switch==1
        
       end
   end

   
    /////////// SevenSegment //////////
    reg [7:0] seg0,seg1,seg2,seg3,seg4,seg5,seg6,seg7;
    //reg [1:0] bomb_type;
    
    always@(*)
    begin:SevSeg
        seg1 <= show_none; seg4 <= show_none; seg6 <= show_none; //沒用到的
        if ( Switch==0 ) begin 
            seg0 <= show_1; //關卡1
            seg7 <= show_1;   //炸彈種類1            
            if (state==Stop) begin seg2 <= show_3; seg3 <= show_0; seg5 <= show_1; end// 時間30 剩餘目標顯示1
            else if (state==Move || state==Bomb ) begin       
                if (target==0) begin seg2 <= seg2; seg3 <= seg3; seg5 <= show_0; end    //目標為0 ： 時間不變 剩餘目標顯示0
                else begin  //目標>=1 ： 時間倒數 剩餘目標顯示>=1
                    seg5 <= show_1;
                    case(times) //seg3
                        5'd0,5'd10,5'd20,5'd30: seg3 <=  show_0;
                        5'd1,5'd11,5'd21: seg3 <= show_1;
                        5'd2,5'd12,5'd22: seg3 <= show_2;
                        5'd3,5'd13,5'd23: seg3 <= show_3; 
                        5'd4,5'd14,5'd24: seg3 <= show_4;
                        5'd5,5'd15,5'd25: seg3 <= show_5; 
                        5'd6,5'd16,5'd26: seg3 <= show_6;
                        5'd7,5'd17,5'd27: seg3 <= show_7; 
                        5'd8,5'd18,5'd28: seg3 <= show_8;
                        5'd9,5'd19,5'd29: seg3 <= show_9; 
                        default: seg3 <= show_0;
                    endcase
                    
                    case(times)//seg2
                        5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7,5'd8,5'd9: seg2 <= show_0;
                        5'd10,5'd11,5'd12,5'd13,5'd14,5'd15,5'd16,5'd17,5'd18,5'd19: seg2 <= show_1;
                        5'd20,5'd21,5'd22,5'd23,5'd24,5'd25,5'd26,5'd27,5'd28,5'd29: seg2 <= show_2;
                        5'd30: seg2 <= show_3;//3     
                        default: seg2 <= show_0;
                    endcase
                end //目標為1  
            end //Move and Bomb
            else begin seg2<=seg2; seg3<=seg3; seg5<=seg5; end //Win and Die：時間維持 剩餘目標維持
        end // switch0  ( 關卡1 )
        
        else begin 
            seg0 <= show_2; //關卡2
            case(outdata)
                2'd0:seg7 <= show_1;   //炸彈種類1  
                2'd1:seg7 <= show_2;   //炸彈種類2  
                2'd2:seg7 <= show_3;   //炸彈種類3  
                2'd3:seg7 <= show_4;   //炸彈種類4  
                default:seg7 <= show_none;  
            endcase
            if (state==Stop) begin seg2 <= show_6; seg3 <= show_0; seg5 <= show_6; end// 時間60 剩餘目標顯示6
            else if (state==Move || state==Bomb ) begin       
                 if (target2==0) begin seg2 <= seg2; seg3 <= seg3; seg5 <= show_0; end    //目標為0 ： 時間不變 剩餘目標顯示0
                 else begin  //目標>=1 ： 時間倒數 剩餘目標顯示>=1
                   case(target2) //seg3
                        5'd1 : seg5 <= show_1;
                        5'd2 : seg5 <= show_2;
                        5'd3 : seg5 <= show_3; 
                        5'd4 : seg5 <= show_4;
                        5'd5 : seg5 <= show_5; 
                        5'd6 : seg5 <= show_6;
                        default: seg5 <= show_none;
                    endcase
                    case(times2) //seg3
                        5'd0,5'd10,5'd20,5'd30, 6'd40,6'd50,6'd60,8'd70 : seg3 <= show_0;
                        5'd1,5'd11,5'd21,6'd31, 6'd41,6'd51,8'd61,8'd71 : seg3 <= show_1;
                        5'd2,5'd12,5'd22,6'd32, 6'd42,6'd52,8'd62,8'd72 : seg3 <= show_2;
                        5'd3,5'd13,5'd23,6'd33, 6'd43,6'd53,8'd63,8'd73 : seg3 <= show_3; 
                        5'd4,5'd14,5'd24,6'd34, 6'd44,6'd54,8'd64,8'd74 : seg3 <= show_4;
                        5'd5,5'd15,5'd25,6'd35, 6'd45,6'd55,8'd65,8'd75 : seg3 <= show_5; 
                        5'd6,5'd16,5'd26,6'd36, 6'd46,6'd56,8'd66,8'd76 : seg3 <= show_6;
                        5'd7,5'd17,5'd27,6'd37, 6'd47,6'd57,8'd67,8'd77 : seg3 <= show_7; 
                        5'd8,5'd18,5'd28,6'd38, 6'd48,6'd58,8'd68,8'd78 : seg3 <= show_8;
                        5'd9,5'd19,5'd29,6'd39, 6'd49,6'd59,8'd69,8'd79 : seg3 <= show_9; 
                        default: seg3 <= show_none;
                    endcase
                if (times2 < 6'd10)                          begin seg2 <= show_0; end                    
                else if (times2 >= 6'd10 && times2 < 6'd20)  begin seg2 <= show_1; end
                else if (times2 >= 6'd20 && times2 < 6'd30)  begin seg2 <= show_2; end    
                else if (times2 >= 6'd30 && times2 < 6'd40)  begin seg2 <= show_3; end
                else if (times2 >= 6'd40 && times2 < 6'd50)  begin seg2 <= show_4; end
                else if (times2 >= 6'd50 && times2 < 6'd60)  begin seg2 <= show_5; end
                else if (times2 >= 6'd60 && times2 < 8'd70)  begin seg2 <= show_6; end 
                else if (times2 >= 8'd70 && times2 < 8'd80)  begin seg2 <= show_7; end    
                else                                         begin seg2 <= show_none;    end             
                
                end //目標為1  
            end //Move and Bomb
            
        end // switch==1：關卡2
    end//always

////////// Enable ///////////
    reg [2:0]segcount;
    always@(posedge clk1 or negedge rst)begin
        if(!rst) segcount<=2'b0;
        else begin
           segcount<=segcount+2'b1;
            case(segcount)
                4'd0:begin en<=8'b1000_0000; SevenSeg_g0<= seg0; end
                4'd1:begin en<=8'b0100_0000; SevenSeg_g0<= seg1; end
                4'd2:begin en<=8'b0010_0000; SevenSeg_g0<= seg2; end
                4'd3:begin en<=8'b0001_0000; SevenSeg_g0<= seg3; end
                4'd4:begin en<=8'b0000_1000; SevenSeg_g1<= seg4; end
                4'd5:begin en<=8'b0000_0100; SevenSeg_g1<= seg5; end
                4'd6:begin en<=8'b0000_0010; SevenSeg_g1<= seg6; end
                4'd7:begin en<=8'b0000_0001; SevenSeg_g1<= seg7; end
       
            endcase
        end
    end 
    
    /////////// LED //////////
    reg [2:0]aaa;
    always@(posedge clk2 or negedge rst)
    begin:LED
        if(!rst) begin led<=16'b0000_0000_0000_0000; aaa<=3'd0; end
        else begin
            if(state==Move||state==Stop||state==Bomb) begin led<=16'b0000_0000_0000_0000; aaa<=3'd0; end
            else if(state==Win) begin            
                    case(aaa)
                    3'd0: begin led<=16'b0000_0000_0000_0000; aaa<=3'd1; end
                    3'd1: begin led<=16'b1000_1000_1000_1000; aaa<=3'd2; end
                    3'd2: begin led<=16'b1100_1100_1100_1100; aaa<=3'd3; end
                    3'd3: begin led<=16'b1110_1110_1110_1110; aaa<=3'd4; end
                    3'd4: begin led<=16'b1111_1111_1111_1111; aaa<=3'd5; end
                    3'd5: begin led<=16'b0111_0111_0111_0111; aaa<=3'd6; end
                    3'd6: begin led<=16'b0011_0011_0011_0011; aaa<=3'd7; end
                    3'd7: begin led<=16'b0001_0001_0001_0001; aaa<=3'd0; end 
                    default: begin led<=16'b0000_0000_0000_0000; aaa<=3'd1; end
                    endcase
           end          
           else begin // Die
                    case(aaa)
                    3'd0: begin led<=16'b0000_0000_0000_0000; aaa<=3'd1; end
                    3'd1: begin led<=16'b0000_0011_1100_0000; aaa<=3'd2; end
                    3'd2: begin led<=16'b0000_1111_1111_0000; aaa<=3'd3; end
                    3'd3: begin led<=16'b0011_1111_1111_1100; aaa<=3'd4; end
                    3'd4: begin led<=16'b1111_1111_1111_1111; aaa<=3'd5; end
                    3'd5: begin led<=16'b0011_1111_1111_1100; aaa<=3'd6; end
                    3'd6: begin led<=16'b0000_1111_1111_0000; aaa<=3'd7; end
                    3'd7: begin led<=16'b0000_0011_1100_0000; aaa<=3'd0; end 
                    default: begin led<=16'b0000_0000_0000_0000; aaa<=3'd1; end
                    endcase
            end       
        end// rst
    end//always


      // 地圖產生
   logo_rom1 r1 (.clka(pclk),.addra(ROM_addr),.douta(person_rom_dout)); // person_rom
   logo_rom2 r2 (.clka(pclk),.addra(ROM_addr),.douta(bomb1_rom_dout));   // bomb_rom       
   logo_rom3 r3 (.clka(pclk),.addra(ROM_addr),.douta(block_rom_dout));  // block_rom        
   logo_rom4 r4 (.clka(pclk),.addra(ROM_addr),.douta(house_rom_dout));
   logo_rom5 r5 (.clka(pclk),.addra(ROM_addr),.douta(tree_rom_dout));        
   logo_rom6 r6 (.clka(pclk),.addra(ROM_addr),.douta(target_rom_dout)); 
   
   zero_rom r7 (.clka(pclk),.addra(zero_addr),.douta(zero_rom_dout)); 
   one_rom r8 (.clka(pclk),.addra(one_addr),.douta(one_rom_dout)); 
   two_rom r9 (.clka(pclk),.addra(two_addr),.douta(two_rom_dout));
   three_rom r10 (.clka(pclk),.addra(three_addr),.douta(three_rom_dout) );
   four_rom r11 (.clka(pclk),.addra(four_addr),.douta(four_rom_dout) );
   
   poison_rom r12 (.clka(pclk),.addra(ROM_addr),.douta(poison_rom_dout) );
   Q_rom r13 (.clka(pclk),.addra(ROM_addr),.douta(Q_rom_dout) );
   W_rom r14 (.clka(pclk),.addra(ROM_addr),.douta(W_rom_dout) );
   E_rom r15 (.clka(pclk),.addra(ROM_addr),.douta(E_rom_dout) );
   help_rom r16 (.clka(pclk),.addra(ROM_addr),.douta(help_rom_dout) );
   
//   bombF_rom r17 (.clka(pclk),.addra(bombF_addr),.douta(bombF_rom_dout));
   bombQ_rom r18 (.clka(pclk),.addra(bombQ_addr),.douta(bombQ_rom_dout));
   bombW_rom r19 (.clka(pclk),.addra(bombW_addr),.douta(bombW_rom_dout));
   bombE_rom r20 (.clka(pclk),.addra(bombE_addr),.douta(bombE_rom_dout));
    
   SyncGeneration u6 (.pclk(pclk), .reset(rst), .hSync(hsync), .vSync(vsync), .dataValid(valid), .hDataCnt(h_cnt), .vDataCnt(v_cnt));
   
   parameter logo_length = 30, logo_height = 50, logo_time_length = 80, logo_time_height = 100, bomb_length = 30, bomb_height = 50; 
   
   assign person_logo_area = ( person_explode == 0 &
                              (h_cnt>=person_x) & (h_cnt<=person_x + logo_length -1) & (v_cnt>=person_y) & (v_cnt<=person_y + logo_height -1) )? 1'b1:1'b0;  
   
   assign block1_logo_area = ( block1_explode == 0 & 
                               (h_cnt>=block1_x) & (h_cnt<=block1_x + logo_length -1) & (v_cnt>=block1_y) & (v_cnt<=block1_y + logo_height -1))? 1'b1:1'b0;
   assign block2_logo_area = ( block2_explode == 0 & 
                               (h_cnt>=block2_x) & (h_cnt<=block2_x + logo_length -1) & (v_cnt>=block2_y) & (v_cnt<=block2_y + logo_height -1))? 1'b1:1'b0;
   assign block3_logo_area = ( block3_explode == 0 & 
                               (h_cnt>=block3_x) & (h_cnt<=block3_x + logo_length -1) & (v_cnt>=block3_y) & (v_cnt<=block3_y + logo_height -1))? 1'b1:1'b0;
   assign block4_logo_area = ( block4_explode == 0 & 
                               (h_cnt>=block4_x) & (h_cnt<=block4_x + logo_length -1) & (v_cnt>=block4_y) & (v_cnt<=block4_y + logo_height -1))? 1'b1:1'b0;
   
   assign house1_logo_area = ( (h_cnt>=house1_x) & (h_cnt<=house1_x + logo_length -1) & (v_cnt>=house1_y) & (v_cnt<=house1_y + logo_height -1))? 1'b1:1'b0;
   assign house2_logo_area = ( (h_cnt>=house2_x) & (h_cnt<=house2_x + logo_length -1) & (v_cnt>=house2_y) & (v_cnt<=house2_y + logo_height -1))? 1'b1:1'b0;
   assign house3_logo_area = ( (h_cnt>=house3_x) & (h_cnt<=house3_x + logo_length -1) & (v_cnt>=house3_y) & (v_cnt<=house3_y + logo_height -1))? 1'b1:1'b0;  
   
   assign tree1_logo_area = ( (h_cnt>=tree1_x) & (h_cnt<=tree1_x + logo_length -1) & (v_cnt>=tree1_y) & (v_cnt<=tree1_y + logo_height -1))? 1'b1:1'b0;
   assign tree2_logo_area = ( (h_cnt>=tree2_x) & (h_cnt<=tree2_x + logo_length -1) & (v_cnt>=tree2_y) & (v_cnt<=tree2_y + logo_height -1))? 1'b1:1'b0;
   assign tree3_logo_area = ( (h_cnt>=tree3_x) & (h_cnt<=tree3_x + logo_length -1) & (v_cnt>=tree3_y) & (v_cnt<=tree3_y + logo_height -1))? 1'b1:1'b0;
   
   assign target_logo_area = ( (h_cnt>=target_x) & (h_cnt<=target_x + logo_length -1) & (v_cnt>=target_y) & (v_cnt<=target_y + logo_height -1))? 1'b1:1'b0;
   
   assign zero_logo_area1 = ( (NS != Bomb | bomb_time == 0) & 
                              (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign one_logo_area1 = ( bomb_time == 1 & 
                            (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign two_logo_area1 = ( bomb_time == 2 &
                            (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign three_logo_area1 = ( NS == Bomb & (bomb_time == 3 | bomb_time == 4) & 
                              (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   
   assign zero_logo_area2 = ( (NS != Bomb | bombF_time == 0 | bombQ_time == 0 | bombW_time == 0 | bombE_time == 0)  & 
                             (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign one_logo_area2 = ( (((outdata==0 & (bombF_time == 1 | bombF_time == 2)) | bombQ_time == 1 | bombW_time == 1 | bombE_time == 1))  & 
                            (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign two_logo_area2 = ( (((outdata==1 & (bombQ_time == 2 | bombQ_time == 3)) | bombW_time == 2 | bombE_time == 2))  & 
                            (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign three_logo_area2 = ( ((outdata==2 & (bombW_time == 3 | bombW_time == 4)) | bombE_time == 3)  & 
                              (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
   assign four_logo_area2 = ( (NS == Bomb & outdata==3 & (bombE_time == 4 | bombE_time == 5)) & 
                              (h_cnt>=time_x) & (h_cnt<=time_x + logo_time_length -1) & (v_cnt>=time_y) & (v_cnt<=time_y + logo_time_height -1))? 1'b1:1'b0;
                                                          
   assign line_area=((v_cnt>=0) & (v_cnt<=5) & (h_cnt>=0) & (h_cnt<=320) |                      
                     (v_cnt>=475) & (v_cnt<=480) & (h_cnt>=0) & (h_cnt<=320) |                   
                     (v_cnt>=6) & (v_cnt<=474) & (h_cnt>=0) & (h_cnt<=5) |
                     (v_cnt>=6) & (v_cnt<=474) & (h_cnt>=316) & (h_cnt<=320)  ) ? 1'b1:1'b0;
   assign bomb_area =  ( NS == Bomb & 
                        (h_cnt>=bomb_x) & (h_cnt<=bomb_x + bomb_length -1) & (v_cnt>=bomb_y) & (v_cnt<=bomb_y + bomb_height -1))? 1'b1:1'b0;
 
   integer mm;
   always@(*) begin
        for(mm=0; mm<=11; mm=mm+1)begin         
                block_area[mm] = ( block_explode[mm] == 0 & (h_cnt>=block_x[mm]) & (h_cnt<=block_x[mm] + logo_length -1) & (v_cnt>=block_y[mm]) & (v_cnt<=block_y[mm] + logo_height -1))? 1'b1:1'b0;      
        end
        for(mm=0; mm<=7; mm=mm+1)begin         
                tree_area[mm]=((h_cnt>=tree_x[mm]) & (h_cnt<=tree_x[mm] + logo_length -1) & (v_cnt>=tree_y[mm]) & (v_cnt<=tree_y[mm] + logo_height -1))? 1'b1:1'b0;      
        end
        for(mm=0; mm<=9; mm=mm+1)begin         
                house_area[mm]=((h_cnt>=house_x[mm]) & (h_cnt<=house_x[mm] + logo_length -1) & (v_cnt>=house_y[mm]) & (v_cnt<=house_y[mm] + logo_height -1))? 1'b1:1'b0;      
        end
   end 
   
   assign poison_area = ((h_cnt>=poison_x) & (h_cnt<=poison_x + logo_length -1) & (v_cnt>=poison_y) & (v_cnt<=poison_y + logo_height -1))? 1'b1:1'b0;
   assign Q1_area = (Q_explode[1] == 0 &(h_cnt>=Q1_x) & (h_cnt<=Q1_x + logo_length -1) & (v_cnt>=Q1_y) & (v_cnt<=Q1_y + logo_height -1))? 1'b1:1'b0;
   assign Q2_area = (Q_explode[2] == 0 &(h_cnt>=Q2_x) & (h_cnt<=Q2_x + logo_length -1) & (v_cnt>=Q2_y) & (v_cnt<=Q2_y + logo_height -1))? 1'b1:1'b0;
   assign W1_area = (W_explode[1] == 0 &(h_cnt>=W1_x) & (h_cnt<=W1_x + logo_length -1) & (v_cnt>=W1_y) & (v_cnt<=W1_y + logo_height -1))? 1'b1:1'b0;
   assign W2_area = (W_explode[2] == 0 &(h_cnt>=W2_x) & (h_cnt<=W2_x + logo_length -1) & (v_cnt>=W2_y) & (v_cnt<=W2_y + logo_height -1))? 1'b1:1'b0;
   assign E1_area = (E_explode[1] == 0 &(h_cnt>=E1_x) & (h_cnt<=E1_x + logo_length -1) & (v_cnt>=E1_y) & (v_cnt<=E1_y + logo_height -1))? 1'b1:1'b0;
   assign E2_area = (E_explode[2] == 0 &(h_cnt>=E2_x) & (h_cnt<=E2_x + logo_length -1) & (v_cnt>=E2_y) & (v_cnt<=E2_y + logo_height -1))? 1'b1:1'b0;
   assign help_area = ( s == 0 &
                        (h_cnt>=help_x) & (h_cnt<=help_x + logo_length -1) & (v_cnt>=help_y) & (v_cnt<=help_y + logo_height -1))? 1'b1:1'b0;
   assign bombF_area =  ( NS == Bomb & outdata == 0 &
                          (h_cnt>=bombF_x) & (h_cnt<=bombF_x + bomb_length -1) & (v_cnt>=bombF_y) & (v_cnt<=bombF_y + bomb_height -1))? 1'b1:1'b0;
   assign bombQ_area =  ( NS == Bomb & outdata == 1 &
                          (h_cnt>=bombQ_x) & (h_cnt<=bombQ_x + bomb_length -1) & (v_cnt>=bombQ_y) & (v_cnt<=bombQ_y + bomb_height -1))? 1'b1:1'b0;
   assign bombW_area =  ( NS == Bomb & outdata == 2 &
                          (h_cnt>=bombW_x) & (h_cnt<=bombW_x + bomb_length -1) & (v_cnt>=bombW_y) & (v_cnt<=bombW_y + bomb_height -1))? 1'b1:1'b0;
   assign bombE_area =  ( NS == Bomb & outdata == 3 &
                          (h_cnt>=bombE_x) & (h_cnt<=bombE_x + bomb_length -1) & (v_cnt>=bombE_y) & (v_cnt<=bombE_y + bomb_height -1))? 1'b1:1'b0;
   

   integer ii; 
   always @(posedge pclk or negedge rst)
   begin: logo_display
      if (!rst) begin
        ROM_addr <= 11'd0;
        for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=11'd0;
        zero_addr <= 15'd0; one_addr <= 15'd0; two_addr <= 15'd0; three_addr <= 15'd0; 
        bomb1_addr <=  11'd0;  
//        bomb2_addr <=  11'd0;  bomb3_addr <=  11'd0;  bomb4_addr <=  11'd0; 
        bombF_addr <= 11'd0; bombQ_addr <= 11'd0; bombW_addr <= 11'd0; bombE_addr <= 11'd0; 
        for(ii=0 ; ii<=11 ; ii=ii+1) block_addr[ii] <= 11'd0;
        for(ii=0 ; ii<=7 ; ii=ii+1) tree_addr[ii] <= 11'd0;
        for(ii=0 ; ii<=9 ; ii=ii+1) house_addr[ii] <= 11'd0;
        vga_data <= 12'd0;      
        end
      else 
      begin
        if(Switch==0)begin
             if (valid == 1'b1)
             begin
                if (person_logo_area == 1'b1)//11 person
                    begin rom_addr[1] <= rom_addr[1] + 11'd1; ROM_addr <= rom_addr[1]; vga_data <= person_rom_dout; end
                else if (block1_logo_area == 1'b1) //23 block1
                    begin rom_addr[2] <= rom_addr[2] + 11'd1; ROM_addr <= rom_addr[2]; vga_data <= block_rom_dout; end
                else if (block2_logo_area == 1'b1)  //27 block2
                    begin rom_addr[3] <= rom_addr[3] + 11'd1; ROM_addr <= rom_addr[3]; vga_data <= block_rom_dout; end
                else if (block3_logo_area == 1'b1)  //43 block3
                    begin rom_addr[4] <= rom_addr[4] + 11'd1; ROM_addr <= rom_addr[4]; vga_data <= block_rom_dout; end
                else if (block4_logo_area == 1'b1)  //47 block4
                    begin rom_addr[5] <= rom_addr[5] + 11'd1; ROM_addr <= rom_addr[5]; vga_data <= block_rom_dout; end
                else if (house1_logo_area == 1'b1)  //13 house1
                    begin rom_addr[6] <= rom_addr[6] + 11'd1; ROM_addr <= rom_addr[6]; vga_data <= house_rom_dout; end
                else if (house2_logo_area == 1'b1)  //34 house2
                    begin rom_addr[7] <= rom_addr[7] + 11'd1; ROM_addr <= rom_addr[7]; vga_data <= house_rom_dout; end
                else if (house3_logo_area == 1'b1)  //52 house3
                    begin rom_addr[8] <= rom_addr[8] + 11'd1; ROM_addr <= rom_addr[8]; vga_data <= house_rom_dout; end
                else if (tree1_logo_area == 1'b1)  //53 tree1
                    begin rom_addr[9] <= rom_addr[9] + 11'd1; ROM_addr <= rom_addr[9]; vga_data <= tree_rom_dout; end
                else if (tree2_logo_area == 1'b1)  //62 tree2
                    begin rom_addr[10] <= rom_addr[10] + 11'd1;  ROM_addr <= rom_addr[10]; vga_data <= tree_rom_dout; end
                else if (tree3_logo_area == 1'b1)  //71 tree3
                    begin rom_addr[11] <= rom_addr[11] + 11'd1; ROM_addr <= rom_addr[11]; vga_data <= tree_rom_dout; end
                else if (target_logo_area == 1'b1)  //18 targer
                    begin rom_addr[12] <= rom_addr[12] + 11'd1; ROM_addr <= rom_addr[12]; vga_data <= target_rom_dout; end     
                //  炸彈顯示  //
                else if (bomb_area == 1'b1)  //18 targer
                    begin bomb1_addr <= bomb1_addr + 11'd1; ROM_addr <= bomb1_addr; vga_data <= bomb1_rom_dout; end             
                // 炸彈倒數時間顯示 //
                else if (zero_logo_area1 == 1'b1)  //18 targer
                    begin  zero_addr <= zero_addr + 15'd1; vga_data <= zero_rom_dout; end
                else if (one_logo_area1 == 1'b1)  //18 targer
                    begin one_addr <= one_addr + 15'd1; vga_data <= one_rom_dout; end
                else if (two_logo_area1 == 1'b1)  //18 targer
                    begin two_addr <= two_addr + 15'd1; vga_data <= two_rom_dout; end
                else if (three_logo_area1 == 1'b1)  //18 targer
                    begin  three_addr <= three_addr + 15'd1; vga_data <= three_rom_dout; end            
                   // 邊界顯示 //
                else if (line_area) vga_data<=12'b0000_0000_1111;        
                else begin
                    ROM_addr <= ROM_addr;     
                    for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=rom_addr[ii];  
                    zero_addr <= zero_addr; one_addr <= one_addr; two_addr <= two_addr; three_addr <= three_addr;
                    bomb1_addr <= bomb1_addr; 
//                    bomb2_addr <= bomb2_addr; bomb3_addr <= bomb3_addr; bomb4_addr <= bomb4_addr;
                    vga_data <= 12'hfff;              
                end         
             end
             else begin
                vga_data <= 12'h000;
                if (v_cnt == 0)
                begin
                    ROM_addr <= 11'd0;     
                    for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=11'd0; 
                    zero_addr <= 15'd0; one_addr <= 15'd0; two_addr <= 15'd0; three_addr <= 15'd0;
                    bomb1_addr <= 11'd0; 
                end
                else begin
                   ROM_addr<=ROM_addr;     
                   for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=rom_addr[ii]; 
                   zero_addr <= zero_addr; one_addr <= one_addr; two_addr <= two_addr; three_addr <= three_addr;
                   bomb1_addr <= bomb1_addr; 
                end
             end
          end///// switch0 關卡一
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////                         
          // Switch1 關卡二 //
          else begin
            if (valid == 1'b1)
             begin
                if (person_logo_area == 1'b1)  //11 person
                   begin rom_addr[13] <= rom_addr[13] + 11'd1; ROM_addr <= rom_addr[13]; vga_data <= person_rom_dout; end 
                  // 邊界顯示 //
                else if (line_area) vga_data<=12'h000;
                else if (poison_area == 1'b1)  //82 pois
                    begin rom_addr[14] <= rom_addr[14] + 11'd1; ROM_addr <= rom_addr[14]; vga_data <= poison_rom_dout; end
 
                else if (block_area[0] == 1) // block
                    begin  block_addr[0] <= block_addr[0] + 11'd1; ROM_addr <= block_addr[0]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[1] == 1) // block
                    begin  block_addr[1] <= block_addr[1] + 11'd1; ROM_addr <= block_addr[1]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[2] == 1) // block
                    begin  block_addr[2] <= block_addr[2] + 11'd1; ROM_addr <= block_addr[2]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[3] == 1) // block
                    begin  block_addr[3] <= block_addr[3] + 11'd1; ROM_addr <= block_addr[3]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[4] == 1) // block
                    begin  block_addr[4] <= block_addr[4] + 11'd1; ROM_addr <= block_addr[4]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[5] == 1) // block
                    begin  block_addr[5] <= block_addr[5] + 11'd1; ROM_addr <= block_addr[5]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[6] == 1) // block
                    begin  block_addr[6] <= block_addr[6] + 11'd1; ROM_addr <= block_addr[6]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[7] == 1) // block
                    begin  block_addr[7] <= block_addr[7] + 11'd1; ROM_addr <= block_addr[7]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[8] == 1) // block
                    begin  block_addr[8] <= block_addr[8] + 11'd1; ROM_addr <= block_addr[8]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[9] == 1) // block
                    begin  block_addr[9] <= block_addr[9] + 11'd1; ROM_addr <= block_addr[9]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[10] == 1) // block
                    begin  block_addr[10] <= block_addr[10] + 11'd1; ROM_addr <= block_addr[10]; vga_data <= block_rom_dout; end// block1-12 
                else if (block_area[11] == 1) // block
                    begin  block_addr[11] <= block_addr[11] + 11'd1; ROM_addr <= block_addr[11]; vga_data <= block_rom_dout; end// block1-12 
                
                else if (tree_area[0] == 1) // tree
                    begin  tree_addr[0] <= tree_addr[0] + 11'd1; ROM_addr <= tree_addr[0]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[1] == 1) // tree
                    begin  tree_addr[1] <= tree_addr[1] + 11'd1; ROM_addr <= tree_addr[1]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[2] == 1) // tree
                    begin  tree_addr[2] <= tree_addr[2] + 11'd1; ROM_addr <= tree_addr[2]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[3] == 1) // tree
                    begin  tree_addr[3] <= tree_addr[3] + 11'd1; ROM_addr <= tree_addr[3]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[4] == 1) // tree
                    begin  tree_addr[4] <= tree_addr[4] + 11'd1; ROM_addr <= tree_addr[4]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[5] == 1) // tree
                    begin  tree_addr[5] <= tree_addr[5] + 11'd1; ROM_addr <= tree_addr[5]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[6] == 1) // tree
                    begin  tree_addr[6] <= tree_addr[6] + 11'd1; ROM_addr <= tree_addr[6]; vga_data <= tree_rom_dout; end// tree1-12 
                else if (tree_area[7] == 1) // tree
                    begin  tree_addr[7] <= tree_addr[7] + 11'd1; ROM_addr <= tree_addr[7]; vga_data <= tree_rom_dout; end// tree1-12     
                
                else if (house_area[0] == 1) // house
                    begin  house_addr[0] <= house_addr[0] + 11'd1; ROM_addr <= house_addr[0]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[1] == 1) // house
                    begin  house_addr[1] <= house_addr[1] + 11'd1; ROM_addr <= house_addr[1]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[2] == 1) // house
                    begin  house_addr[2] <= house_addr[2] + 11'd1; ROM_addr <= house_addr[2]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[3] == 1) // house
                    begin  house_addr[3] <= house_addr[3] + 11'd1; ROM_addr <= house_addr[3]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[4] == 1) // house
                    begin  house_addr[4] <= house_addr[4] + 11'd1; ROM_addr <= house_addr[4]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[5] == 1) // house
                    begin  house_addr[5] <= house_addr[5] + 11'd1; ROM_addr <= house_addr[5]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[6] == 1) // house
                    begin  house_addr[6] <= house_addr[6] + 11'd1; ROM_addr <= house_addr[6]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[7] == 1) // house
                    begin  house_addr[7] <= house_addr[7] + 11'd1; ROM_addr <= house_addr[7]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[8] == 1) // house
                    begin  house_addr[8] <= house_addr[8] + 11'd1; ROM_addr <= house_addr[8]; vga_data <= house_rom_dout; end// house1-12 
                else if (house_area[9] == 1) // house
                    begin  house_addr[9] <= house_addr[9] + 11'd1; ROM_addr <= house_addr[9]; vga_data <= house_rom_dout; end// house1-12    
                    
                else if (Q1_area == 1) // Q1
                    begin  rom_addr[15] <= rom_addr[15] + 11'd1; ROM_addr <= rom_addr[15]; vga_data <= Q_rom_dout; end// Q35  
                else if (Q2_area == 1) // Q2
                    begin  rom_addr[16] <= rom_addr[16] + 11'd1; ROM_addr <= rom_addr[16]; vga_data <= Q_rom_dout; end// Q65  
                else if (W1_area == 1) // W1
                    begin  rom_addr[17] <= rom_addr[17] + 11'd1; ROM_addr <= rom_addr[17]; vga_data <= W_rom_dout; end// W27  
                else if (W2_area == 1) // W1
                    begin  rom_addr[18] <= rom_addr[18] + 11'd1; ROM_addr <= rom_addr[18]; vga_data <= W_rom_dout; end// W77 
                else if (E1_area == 1) // E1
                    begin  rom_addr[19] <= rom_addr[19] + 11'd1; ROM_addr <= rom_addr[19]; vga_data <= E_rom_dout; end// E47       
                else if (E2_area == 1) // E1
                    begin  rom_addr[20] <= rom_addr[20] + 11'd1; ROM_addr <= rom_addr[20]; vga_data <= E_rom_dout; end// E57        
                else if (help_area == 1) // help
                    begin  rom_addr[21] <= rom_addr[21] + 11'd1; ROM_addr <= rom_addr[21]; vga_data <= help_rom_dout; end// help81                      
                //  炸彈顯示  //
                else if (bombF_area == 1'b1)  //18 targer
                    begin bombF_addr <= bombF_addr + 11'd1; ROM_addr <= bombF_addr; vga_data <= bomb1_rom_dout; end   
                else if (bombQ_area == 1'b1)  //18 targer
                    begin bombQ_addr <= bombQ_addr + 11'd1; vga_data <= bombQ_rom_dout; end 
                else if (bombW_area == 1'b1)  //18 targer
                    begin bombW_addr <= bombW_addr + 11'd1; vga_data <= bombW_rom_dout; end
                else if (bombE_area == 1'b1)  //18 targer
                    begin bombE_addr <= bombE_addr + 11'd1; vga_data <= bombE_rom_dout; end             
                // 炸彈倒數時間顯示 //
                else if (zero_logo_area2 == 1'b1)  //18 targer
                    begin  zero_addr <= zero_addr + 15'd1; vga_data <= zero_rom_dout; end
                else if (one_logo_area2 == 1'b1)  //18 targer
                    begin one_addr <= one_addr + 15'd1; vga_data <= one_rom_dout; end
                else if (two_logo_area2 == 1'b1)  //18 targer
                    begin two_addr <= two_addr + 15'd1; vga_data <= two_rom_dout; end
                else if (three_logo_area2 == 1'b1)  //18 targer
                    begin  three_addr <= three_addr + 15'd1; vga_data <= three_rom_dout; end 
                else if (four_logo_area2 == 1'b1)  //18 targer
                    begin  four_addr <= four_addr + 15'd1; vga_data <= four_rom_dout; end 
                                 
                else begin
                    ROM_addr <= ROM_addr;     
                    for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=rom_addr[ii];  
                    zero_addr <= zero_addr; one_addr <= one_addr; two_addr <= two_addr; three_addr <= three_addr; four_addr <= four_addr;
                    bombF_addr <= bombF_addr; bombQ_addr <= bombQ_addr; bombW_addr <= bombW_addr; bombE_addr <= bombE_addr;
                    for(ii=0 ; ii<=11 ; ii=ii+1) block_addr[ii]<=block_addr[ii];
                    for(ii=0 ; ii<=7 ; ii=ii+1)  tree_addr[ii]<=tree_addr[ii];
                    for(ii=0 ; ii<=9 ; ii=ii+1)  house_addr[ii]<=house_addr[ii];
                    vga_data <= 12'hfff;              
                    end                     
             end//valid
             else begin
                vga_data <= 12'h000;
                if (v_cnt == 0) begin
                    ROM_addr <= 11'd0;     
                    for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=11'd0;                     
                    zero_addr <= 15'd0; one_addr <= 15'd0; two_addr <= 15'd0; three_addr <= 15'd0; four_addr <= 15'd0;
                    bombF_addr <= 11'd0; bombQ_addr <= 11'd0; bombW_addr <= 11'd0; bombE_addr <= 11'd0; 
                    for(ii=0 ; ii<=11 ; ii=ii+1) block_addr[ii]<=11'd0;
                    for(ii=0 ; ii<=7 ; ii=ii+1)  tree_addr[ii]<=11'd0;
                    for(ii=0 ; ii<=9 ; ii=ii+1)  house_addr[ii]<=11'd0;
                end
                else begin
                   ROM_addr<=ROM_addr;     
                   for(ii=1 ; ii<=30 ; ii=ii+1) rom_addr[ii]<=rom_addr[ii];                  
                   zero_addr <= zero_addr; one_addr <= one_addr; two_addr <= two_addr; three_addr <= three_addr; four_addr <= four_addr;
                   bombF_addr <= bombF_addr; bombQ_addr <= bombQ_addr; bombW_addr <= bombW_addr; bombE_addr <= bombE_addr;
                   for(ii=0 ; ii<=11 ; ii=ii+1) block_addr[ii]<=block_addr[ii];
                   for(ii=0 ; ii<=7 ; ii=ii+1)  tree_addr[ii]<=tree_addr[ii];
                   for(ii=0 ; ii<=9 ; ii=ii+1)  house_addr[ii]<=house_addr[ii];
                end
             end
          end//switch1 
      end
   end
   
   assign {vga_r,vga_g,vga_b} = vga_data;


    always@(posedge pclk or negedge rst)
    begin
        if(!rst) begin
                        
            if (Switch == 0) begin       
                block1_x<=10'd46; block1_y<=10'd306;
                block2_x<=10'd46; block2_y<=10'd66;
                block3_x<=10'd126; block3_y<=10'd306;
                block4_x<=10'd126; block4_y<=10'd66;
                
                house1_x<=10'd6; house1_y<=10'd306;
                house2_x<=10'd86; house2_y<=10'd246;
                house3_x<=10'd166; house3_y<=10'd366;
                
                tree1_x<=10'd166; tree1_y<=10'd306;
                tree2_x<=10'd206; tree2_y<=10'd366;
                tree3_x<=10'd246; tree3_y<=10'd426;
                
                target_x<=10'd6; target_y<=10'd6;
                time_x<=10'd400; time_y<=10'd10;
                end
          else begin
                for(ii=0 ; ii<=3 ; ii=ii+1) block_x[ii]<= 286-80*ii;
                for(ii=4 ; ii<=7 ; ii=ii+1) block_x[ii]<= 246-80*(ii-4);
                for(ii=8 ; ii<=11 ; ii=ii+1) block_x[ii]<= 286-80*(ii-8);                 
                for(ii=0 ; ii<=3 ; ii=ii+1) block_y[ii]<=10'd366;
                for(ii=4 ; ii<=7 ; ii=ii+1) block_y[ii]<=10'd246;
                for(ii=8 ; ii<=11 ; ii=ii+1) block_y[ii]<=10'd126;
                
                tree_x[0] <= 166;
                for (ii=1 ; ii<=4; ii=ii+1 ) tree_x[ii] <= 246-80*(ii-1);
                for (ii=5 ; ii<=7; ii=ii+1 ) tree_x[ii] <= 286-80*(ii-5);
                tree_y[0] <= 426;
                for (ii=1 ; ii<=4; ii=ii+1 ) tree_y[ii] <= 126;
                for (ii=5 ; ii<=7; ii=ii+1 ) tree_y[ii] <= 6;
                                
                for(ii=0 ; ii<=3 ; ii=ii+1) house_x[ii]<= 246-80*ii;
                for(ii=4 ; ii<=7 ; ii=ii+1) house_x[ii]<= 286-80*(ii-4);
                for(ii=8 ; ii<=9 ; ii=ii+1) house_x[ii]<= 166-80*(ii-8);                 
                for(ii=0 ; ii<=3 ; ii=ii+1) house_y[ii]<=10'd366;
                for(ii=4 ; ii<=7 ; ii=ii+1) house_y[ii]<=10'd246;
                for(ii=8 ; ii<=9 ; ii=ii+1) house_y[ii]<=10'd6;
                
                Q1_x<=86; Q1_y<=186; Q2_x<=206; Q2_y<=186;
                W1_x<=46; W1_y<=66; W2_x<=246; W2_y<=66;
                E1_x<=126; E1_y<=66; E2_x<=166; E2_y<=66;
                help_x<=286; help_y<=426;

                end 
        end
        else begin
            person_x <= person_next_x; person_y <= person_next_y;
//            poison_x <= poison_next_x; poison_y <= poison_y;
        end   
    end

 
endmodule

/////////// module keyboard //////////
module keyboard (reset, enkeyboard, ps2_clk, ps2_data, outdata);
input reset,enkeyboard,ps2_clk,ps2_data;
output reg[1:0]outdata;// 0(炸彈1)  // 1(炸彈2)  // 2(炸彈3)  //  3(炸彈4)
reg [3:0]count;
reg [8:0]data;
always@(negedge reset or negedge ps2_clk)
begin
    if(!reset) count<=4'b0;
    else if(enkeyboard)
    begin
        if(count!=4'd10) count<=count+1;
        else if(count==4'd10) count<=0;
    end
end
always@(negedge ps2_clk or negedge reset)
begin
    if(!reset) outdata<=2'b0;
    else if(!ps2_clk)
    begin
        case(count)
            4'd1:data[0]<=ps2_data;
            4'd2:data[1]<=ps2_data;
            4'd3:data[2]<=ps2_data;
            4'd4:data[3]<=ps2_data;
            4'd5:data[4]<=ps2_data;
            4'd6:data[5]<=ps2_data;
            4'd7:data[6]<=ps2_data;
            4'd8:data[7]<=ps2_data;
            default:data[8]<=0;
        endcase
        case(data[7:0])
            8'h2B:outdata[1:0]<=2'd0;//F    // 0(炸彈1) 
            8'h15:outdata[1:0]<=2'd1;//Q    // 1(炸彈2) 
            8'h1D:outdata[1:0]<=2'd2;//W   // 2(炸彈3)
            8'h24:outdata[1:0]<=2'd3;//E    //  3(炸彈4)
            default:outdata[1:0]<=outdata[1:0];
        endcase  
    end//ps2_clk
end//always
endmodule

