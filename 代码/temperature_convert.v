//==================================================================
//--3��ʽ״̬����Moore��ʵ�ֵ�dht22����
//==================================================================
 
//------------<ģ�鼰�˿�����>----------------------------------------
module dht22_drive(
	input 				sys_clk		,		//ϵͳʱ�ӣ�10M
	input				rst_n		,		//�͵�ƽ��Ч�ĸ�λ�ź�	
	inout				dht22		,		//�����ߣ�˫���źţ�
	
	output	reg	[31:0]	data_valid	,		//�������Ч���ݣ�λ��32
	output  wire signed [15:0] LED
);
 
//------------<��������>----------------------------------------------
//״̬��״̬���壬ʹ�ö����루onehot code��
localparam	WAIT_2S		= 6'b000001 ,
			START       = 6'b000010 ,
			DELAY_30us  = 6'b000100 ,
			REPLY       = 6'b001000 ,
			DELAY_75us  = 6'b010000 ,
			REV_data	= 6'b100000 ;
//ʱ���������
localparam	T_2S = 1999999	,				//�ϵ�1s��ʱ��������λus
			T_BE = 999	,				//������ʼ�ź�����ʱ�䣬��λus
			T_GO = 30		;				//�����ͷ�����ʱ�䣬��λus
 
//------------<reg����>----------------------------------------------									
reg	[6:0]	cur_state	;					//��̬
reg	[6:0]	next_state	;					//��̬
reg	[5:0]	cnt			;					//50��Ƶ��������1Mhz(1us)
reg			dht22_out	;					//˫���������
reg			dht22_en	;					//˫���������ʹ�ܣ�1�������0�����̬
reg			dht22_d1	;					//�����źŴ�1��
reg			dht22_d2	;					//�����źŴ�2��
reg			clk_us		;					//usʱ��
reg [21:0]	cnt_us		;					//us������,���ɱ�ʾ4.2s
reg [5:0]	bit_cnt		;					//�������ݼ������������Ա�ʾ64λ
reg [39:0]	data_temp	;					//����У���40λ���
reg signed [15:0]  progress_bar;            //�ȴ��Ľ�����
//------------<wire����>----------------------------------------------		
wire		dht22_in	;					//˫����������
wire		dht22_rise	;					//������
wire		dht22_fall	;					//�½���
 
//==================================================================
//===========================<main  code>===========================
//==================================================================

//-----------------------------------------------------------------------
//--˫��˿�ʹ�÷�ʽ�ͽ�����
//-----------------------------------------------------------------------
assign	dht22_in = dht22;							//����̬�Ļ�����������ϵ����ݸ���dht22_in
assign	dht22 =  dht22_en ? dht22_out : 1'bz;		//ʹ��1�������0�����̬
assign  LED = progress_bar;
//-----------------------------------------------------------------------
//--usʱ�����ɣ���Ϊʱ������usΪ��λ����������һ��1us��ʱ�ӻ�ȽϷ���
//-----------------------------------------------------------------------
//100��Ƶ����
always @(posedge sys_clk or negedge rst_n)begin
	if(!rst_n)
		cnt <= 6'd0;
	else if(cnt == 6'd49)				//ÿ50��ʱ��500ns����
		cnt <= 6'd0;
	else
		cnt <= cnt + 1'd1;
end
//����1usʱ��
always @(posedge sys_clk or negedge rst_n)begin
	if(!rst_n)
		clk_us <= 1'b0;
	else  if(cnt == 6'd49)				//ÿ500ns
		clk_us <= ~clk_us;				//ʱ�ӷ�ת
	else
		clk_us <= clk_us;
end
//-----------------------------------------------------------------------
//--���������½��ؼ���·
//-----------------------------------------------------------------------
//��������ϵ������غ��½���
assign	dht22_rise = ~dht22_d2 && dht22_d1;			//������
assign	dht22_fall = ~dht22_d1 && dht22_d2;			//�½���
//dht22���ģ����������غ��½���
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)begin
		dht22_d1 <= 1'b0;				//��λ��ʼΪ0
		dht22_d2 <= 1'b0;				//��λ��ʼΪ0
	end
	else begin
		dht22_d1 <= dht22;				//��1��
		dht22_d2 <= dht22_d1;			//��2��
	end
end
//-----------------------------------------------------------------------
//--����ʽ״̬��
//-----------------------------------------------------------------------
//״̬����һ�Σ�ͬ��ʱ������״̬ת��
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)		
		cur_state <= WAIT_2S;			
	else
		cur_state <= next_state;
end

//״̬���ڶ��Σ�����߼��ж�״̬ת������������״̬ת�ƹ����Լ����
always @(*)begin
	next_state = WAIT_2S;
	case(cur_state)
		WAIT_2S		:begin
			if(cnt_us == T_2S)				//�����ϵ���ʱ��ʱ��	
				next_state = START;			//��ת��START
			else	
				next_state = WAIT_2S;		//����������״̬����
		end	
		START       :begin	
			if(cnt_us == T_BE)				//�����������ߵ�ʱ��
				next_state = DELAY_30us;	//��ת��DELAY_30us
			else
				next_state = START;			//����������״̬����
		end
		DELAY_30us  :begin					
			if(cnt_us == T_GO || dht22_fall)//���������ͷ�����ʱ��
				next_state = REPLY;			//��ת��REPLY
			else
				next_state = DELAY_30us;	//����������״̬����
		end
		REPLY       :begin
			if(cnt_us <= 'd500)begin		//����500us		
				if(dht22_rise)                      //��������Ӧ
					next_state = DELAY_75us;		//��ת��DELAY_75us
				else
					next_state = REPLY;				//����������״̬����
			end	
			else	
				next_state = START;					//����500us��û����������Ӧ����ת��START
		end	
		DELAY_75us  :begin	
			
			if(dht22_fall)                          //�½�����Ӧ
				next_state = REV_data;				//��ת��REV_data
			else 	
				next_state = DELAY_75us;			//����������״̬����
		end	
		REV_data	:begin	
			if( bit_cnt >= 'd40)		//������������40�����ݺ������һ��ʱ����Ϊ����
													//��׽���������ҽ������ݸ���Ϊ40				
				next_state = WAIT_2S;					//״̬��ת��WAIT_2S�����¿�ʼ��һ�ֲɼ�
			else 	
				next_state = REV_data;				//����������״̬����
		end	
		default:next_state = WAIT_2S;					//Ĭ��״̬ΪWAIT_2S
	endcase
end	
 
//״̬�������Σ�ʱ���߼��������
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)begin										//��λ״̬���������						
		dht22_en <= 1'b0;
		dht22_out <= 1'b0;
		cnt_us <= 22'd0;
		bit_cnt <=  6'd0;
		data_temp <= 40'd0;
		progress_bar <= 16'd0; 	
	end
	else 	
		case(cur_state)
			WAIT_2S		:begin
				dht22_en <= 1'b0;						//�ͷ����ߣ����ⲿ��������
				if(cnt_us == T_2S)						
					cnt_us <= 22'd0;					//��ʱ��������������
				else
				begin
				   cnt_us <= cnt_us + 1'd1;			    //��ʱ�����������������ʱ
				   if(cnt_us % 125000 == 0)              //ÿ��12.5ms��������һ
				      if(cnt_us == 125000)
					    progress_bar <= 16'b1000000000000000;
					  else
				        progress_bar <= progress_bar >>> 1;
				end
					
			end
			START		:begin
				dht22_en <= 1'b1;						//ռ������
				dht22_out <= 1'b0;						//����͵�ƽ
				if(cnt_us == T_BE)		
					cnt_us <= 22'd0;					//��ʱ��������������
				else		
					cnt_us <= cnt_us + 1'd1;			//��ʱ�����������������ʱ
			end		
			DELAY_30us	:begin		
				dht22_en <= 1'b0;						//�ͷ����ߣ����ⲿ��������
				if(cnt_us == T_GO || dht22_fall)
					cnt_us <= 22'd0;					//��ʱ��������������
				else                                    
					cnt_us <= cnt_us + 1'd1;            //��ʱ�����������������ʱ
			end	
			REPLY		:begin
				dht22_en <= 1'b0;						//�ͷ����ߣ����ⲿ��������
				if(cnt_us <= 'd500)begin				//��ʱ����500us
                    if(dht22_rise)                      //��������Ӧ
						cnt_us <= 22'd0;				//��ʱ����
					else
						cnt_us <= cnt_us + 1'd1;		//��ʱ�����������������ʱ
				end
				else 
					cnt_us <= 22'd0;					//����500us��û����������Ӧ����������� 
			end	
			DELAY_75us  :begin
				dht22_en <= 1'b0;						//�ͷ����ߣ����ⲿ��������
				if(dht22_fall)                          //�½�����Ӧ
				    begin
					cnt_us <= 22'd0;					//��ʱ����
					bit_cnt <=  6'd0; 					//������ݽ��ռ�����
					end
				else 	
					cnt_us <= cnt_us + 1'd1;			//��ʱ�����������������ʱ
			end
			REV_data	:begin
				dht22_en <= 1'b0;						//�ͷ����ߣ����ⲿ�������ߣ������ȡ״̬
				if(bit_cnt >= 'd40)begin	            //���ݽ������
					cnt_us <= 22'd0;					//��ռ�ʱ��
				end
				else if(dht22_fall)begin				//��⵽�͵�ƽ����˵�����յ�һ������
					bit_cnt <= bit_cnt + 1'd1;			//���ݽ��ռ�����+1
					cnt_us <= 22'd0;					//��ʱ�����¼���
					if(cnt_us <= 'd100)					
						data_temp[39-bit_cnt] <= 1'b0;	//�ܹ����е�ʱ������100us,��˵�����յ�"0"
					else 
						data_temp[39-bit_cnt] <= 1'b1;	//�ܹ����е�ʱ�����100us,��˵�����յ�"1"
				end
				else begin								//��������û�н����꣬��������1�����ݵĽ��ս�����
					bit_cnt <= bit_cnt;				
					data_temp <= data_temp;
					cnt_us <= cnt_us + 1'd1;			//��ʱ����ʱ
				end
			end
			
			default:;		
		endcase
end
 
//У���ȡ�������Ƿ����У�����
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)
		data_valid <= 32'd0;
	else if((data_temp[7:0] == data_temp[39:32] + data_temp[31:24] +
	data_temp[23:16] + data_temp[15:8]))
		data_valid <= data_temp[39:8]; 		//���Ϲ��������Ч���ݸ�ֵ�����
	else
		data_valid <= data_valid;			//�����Ϲ�����������ζ�ȡ�����ݣ�����Ա����ϴε�״̬����
end
		
endmodule

