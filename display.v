module display(
    Clk,
    Reset_n,
    Disp_Data,
    SEL,
    SEG
);
    //--------------------------
    //      输入输出定义
    //--------------------------
    input Clk;//系统时钟
    input Reset_n;//重置
    input [15:0]Disp_Data;//输入的数据
    output reg[7:0]SEL;//晶体管位选
    output reg[7:0]SEG;//晶体管段选

    //--------------------------
    //        变量定义
    //--------------------------
    reg [1:0]num_cnt;//状态标号
    reg clk_5ms;//5ms的脉冲信号
    reg [19:0]div_cnt;//计数器
    integer number[2:0];//储存十进制数字的整形

    //----------------------------
    //取三位数的不同位
    //----------------------------
    always@*
    begin
    number[0]<=Disp_Data%10;
    number[1]<=Disp_Data/10%10;
    number[2]<=Disp_Data/100;
    end
    //----------------------------
    //形成5ms的脉冲波
    //----------------------------
    always@(posedge Clk or negedge Reset_n)
    begin
    if(!Reset_n)
        begin
        clk_5ms<= 0;
        div_cnt <= 0;
        end
    else if(div_cnt == 499_999)//每500000个周期就生成一次脉冲
    begin
        clk_5ms <= 1;
        div_cnt <= 0;
        end
    else
        begin
        clk_5ms <= 0;
        div_cnt <= div_cnt + 1'b1;
        end
    end
      
    //----------------------------
    //状态转移：00-》01-》10-》00
    //----------------------------
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n)
        num_cnt <= 0;
    else
    if(clk_5ms==1)
        begin
        if(num_cnt==2)
        num_cnt <= 0;
        else
        num_cnt <= num_cnt + 1'b1;
        end
    else
        num_cnt <= num_cnt;

    //----------------------------------
    //设置不同状态的位选信号和小数点是否显示
    //----------------------------------
    always@(posedge Clk)
        case(num_cnt)
            0: begin
            SEL <= 8'b11111110;
            SEG[7]=1;
            end
            1: begin
            SEL <= 8'b11111101;
            SEG[7]=0;
            end
            2: begin
            SEL <= 8'b11111011;  
            SEG[7]=1;
            end        
        endcase
    //----------------------------------
    //设置不同状态的段选信号
    //----------------------------------
    always@(posedge Clk)
    case(number[num_cnt])
    0:if(num_cnt!=2)
      SEG[6:0]<=7'b1000000;
      else//若温度为个位数则不用显示十位数上的"0"
      SEG[6:0]<=7'b1111111;
    1:SEG[6:0]<=7'b1111001;
    2:SEG[6:0]<=7'b0100100;
    3:SEG[6:0]<=7'b0110000;
    4:SEG[6:0]<=7'b0011001;
    5:SEG[6:0]<=7'b0010010;
    6:SEG[6:0]<=7'b0000010;
    7:SEG[6:0]<=7'b1111000;
    8:SEG[6:0]<=7'b0000000;
    9:SEG[6:0]<=7'b0010000;
    endcase

endmodule
