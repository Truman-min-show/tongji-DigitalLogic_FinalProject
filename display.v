module display(
    Clk,
    Reset_n,
    Disp_Data,
    SEL,
    SEG
);
    //--------------------------
    //      �����������
    //--------------------------
    input Clk;//ϵͳʱ��
    input Reset_n;//����
    input [15:0]Disp_Data;//���������
    output reg[7:0]SEL;//�����λѡ
    output reg[7:0]SEG;//����ܶ�ѡ

    //--------------------------
    //        ��������
    //--------------------------
    reg [1:0]num_cnt;//״̬���
    reg clk_5ms;//5ms�������ź�
    reg [19:0]div_cnt;//������
    integer number[2:0];//����ʮ�������ֵ�����

    //----------------------------
    //ȡ��λ���Ĳ�ͬλ
    //----------------------------
    always@*
    begin
    number[0]<=Disp_Data%10;
    number[1]<=Disp_Data/10%10;
    number[2]<=Disp_Data/100;
    end
    //----------------------------
    //�γ�5ms�����岨
    //----------------------------
    always@(posedge Clk or negedge Reset_n)
    begin
    if(!Reset_n)
        begin
        clk_5ms<= 0;
        div_cnt <= 0;
        end
    else if(div_cnt == 499_999)//ÿ500000�����ھ�����һ������
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
    //״̬ת�ƣ�00-��01-��10-��00
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
    //���ò�ͬ״̬��λѡ�źź�С�����Ƿ���ʾ
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
    //���ò�ͬ״̬�Ķ�ѡ�ź�
    //----------------------------------
    always@(posedge Clk)
    case(number[num_cnt])
    0:if(num_cnt!=2)
      SEG[6:0]<=7'b1000000;
      else//���¶�Ϊ��λ��������ʾʮλ���ϵ�"0"
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
