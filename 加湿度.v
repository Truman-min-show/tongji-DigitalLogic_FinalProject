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
    input [31:0]Disp_Data;//输入的数据
    output reg[7:0]SEL;//晶体管位选
    output reg[7:0]SEG;//晶体管段选

    //--------------------------
    //        变量定义
    //--------------------------
    reg [15:0]tem;
    reg [15:0]hum;
    reg [2:0]num_cnt;//状态标号
    reg clk_2ms;//2ms的脉冲信号
    reg [19:0]div_cnt;//计数器
    integer number[2:0];//储存十进制数字的整形
    
    assign tem=Disp_Data[15:0];
    assign hum=Disp_Data[31:16];
    //----------------------------
    //取三位数的不同位
    //----------------------------
    always@*
    begin
    number[0]<=tem%10;
    number[1]<=tem/10%10;
    number[2]<=tem/100;
    number[4]<=hum%10;
    number[5]<=hum/10%10;
    number[6]<=hum/100;
    number[7]<=0;
    end
    //----------------------------
    //形成2ms的脉冲波
    //----------------------------
    always@(posedge Clk or negedge Reset_n)
    begin
    if(!Reset_n)
        begin
        clk_2ms<= 0;
        div_cnt <= 0;
        end
    else if(div_cnt == 199_999)//每200000个周期就生成一次脉冲
    begin
        clk_2ms <= 1;
        div_cnt <= 0;
        end
    else
        begin
        clk_2ms <= 0;
        div_cnt <= div_cnt + 1'b1;
        end
    end
      
    //----------------------------
    //状态转移：000-》001-》010-》100-》101-》110-》111-》000
    //----------------------------
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n)
        num_cnt <= 0;
    else
    if(clk_2ms==1)
        begin
        if(num_cnt==2)
        num_cnt <= 4;
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
            4: begin
            SEL <= 8'b11101111;
            SEG[7]=1;
            end
            5: begin
            SEL <= 8'b11011111;
            SEG[7]=1;
            end
            6: begin
            SEL <= 8'b10111111;
            SEG[7]=1;
            end
            7: begin
            SEL <= 8'b01111111;
            SEG[7]=0;
            end 
        endcase
    //----------------------------------
    //设置不同状态的段选信号
    //----------------------------------
    always@(posedge Clk)
    case(number[num_cnt])
    0:if(num_cnt!=2)
      SEG[6:0]<=7'b1000000;
      else//若温度为个位数则不用显示十位数上的“0”
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
