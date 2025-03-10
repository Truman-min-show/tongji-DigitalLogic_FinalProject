//==================================================================
//--3段式状态机（Moore）实现的dht22驱动
//==================================================================
 
//------------<模块及端口声明>----------------------------------------
module dht22_drive(
	input 				sys_clk		,		//系统时钟，10M
	input				rst_n		,		//低电平有效的复位信号	
	inout				dht22		,		//单总线（双向信号）
	
	output	reg	[31:0]	data_valid	,		//输出的有效数据，位宽32
	output  wire signed [15:0] LED
);
 
//------------<参数定义>----------------------------------------------
//状态机状态定义，使用独热码（onehot code）
localparam	WAIT_2S		= 6'b000001 ,
			START       = 6'b000010 ,
			DELAY_30us  = 6'b000100 ,
			REPLY       = 6'b001000 ,
			DELAY_75us  = 6'b010000 ,
			REV_data	= 6'b100000 ;
//时间参数定义
localparam	T_2S = 1999999	,				//上电1s延时计数，单位us
			T_BE = 999	,				//主机起始信号拉低时间，单位us
			T_GO = 30		;				//主机释放总线时间，单位us
 
//------------<reg定义>----------------------------------------------									
reg	[6:0]	cur_state	;					//现态
reg	[6:0]	next_state	;					//次态
reg	[5:0]	cnt			;					//50分频计数器，1Mhz(1us)
reg			dht22_out	;					//双向总线输出
reg			dht22_en	;					//双向总线输出使能，1则输出，0则高阻态
reg			dht22_d1	;					//总线信号打1拍
reg			dht22_d2	;					//总线信号打2拍
reg			clk_us		;					//us时钟
reg [21:0]	cnt_us		;					//us计数器,最大可表示4.2s
reg [5:0]	bit_cnt		;					//接收数据计数器，最大可以表示64位
reg [39:0]	data_temp	;					//包含校验的40位输出
reg signed [15:0]  progress_bar;            //等待的进度条
//------------<wire定义>----------------------------------------------		
wire		dht22_in	;					//双向总线输入
wire		dht22_rise	;					//上升沿
wire		dht22_fall	;					//下降沿
 
//==================================================================
//===========================<main  code>===========================
//==================================================================

//-----------------------------------------------------------------------
//--双向端口使用方式和进度条
//-----------------------------------------------------------------------
assign	dht22_in = dht22;							//高阻态的话，则把总线上的数据赋给dht22_in
assign	dht22 =  dht22_en ? dht22_out : 1'bz;		//使能1则输出，0则高阻态
assign  LED = progress_bar;
//-----------------------------------------------------------------------
//--us时钟生成，因为时序都是以us为单位，所以生成一个1us的时钟会比较方便
//-----------------------------------------------------------------------
//100分频计数
always @(posedge sys_clk or negedge rst_n)begin
	if(!rst_n)
		cnt <= 6'd0;
	else if(cnt == 6'd49)				//每50个时钟500ns清零
		cnt <= 6'd0;
	else
		cnt <= cnt + 1'd1;
end
//生成1us时钟
always @(posedge sys_clk or negedge rst_n)begin
	if(!rst_n)
		clk_us <= 1'b0;
	else  if(cnt == 6'd49)				//每500ns
		clk_us <= ~clk_us;				//时钟反转
	else
		clk_us <= clk_us;
end
//-----------------------------------------------------------------------
//--上升沿与下降沿检测电路
//-----------------------------------------------------------------------
//检测总线上的上升沿和下降沿
assign	dht22_rise = ~dht22_d2 && dht22_d1;			//上升沿
assign	dht22_fall = ~dht22_d1 && dht22_d2;			//下降沿
//dht22打拍，捕获上升沿和下降沿
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)begin
		dht22_d1 <= 1'b0;				//复位初始为0
		dht22_d2 <= 1'b0;				//复位初始为0
	end
	else begin
		dht22_d1 <= dht22;				//打1拍
		dht22_d2 <= dht22_d1;			//打2拍
	end
end
//-----------------------------------------------------------------------
//--三段式状态机
//-----------------------------------------------------------------------
//状态机第一段：同步时序描述状态转移
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)		
		cur_state <= WAIT_2S;			
	else
		cur_state <= next_state;
end

//状态机第二段：组合逻辑判断状态转移条件，描述状态转移规律以及输出
always @(*)begin
	next_state = WAIT_2S;
	case(cur_state)
		WAIT_2S		:begin
			if(cnt_us == T_2S)				//满足上电延时的时间	
				next_state = START;			//跳转到START
			else	
				next_state = WAIT_2S;		//条件不满足状态不变
		end	
		START       :begin	
			if(cnt_us == T_BE)				//满足拉低总线的时间
				next_state = DELAY_30us;	//跳转到DELAY_30us
			else
				next_state = START;			//条件不满足状态不变
		end
		DELAY_30us  :begin					
			if(cnt_us == T_GO || dht22_fall)//满足主机释放总线时间
				next_state = REPLY;			//跳转到REPLY
			else
				next_state = DELAY_30us;	//条件不满足状态不变
		end
		REPLY       :begin
			if(cnt_us <= 'd500)begin		//不到500us		
				if(dht22_rise)                      //上升沿响应
					next_state = DELAY_75us;		//跳转到DELAY_75us
				else
					next_state = REPLY;				//条件不满足状态不变
			end	
			else	
				next_state = START;					//超过500us仍没有上升沿响应则跳转到START
		end	
		DELAY_75us  :begin	
			
			if(dht22_fall)                          //下降沿响应
				next_state = REV_data;				//跳转到REV_data
			else 	
				next_state = DELAY_75us;			//条件不满足状态不变
		end	
		REV_data	:begin	
			if( bit_cnt >= 'd40)		//接收完了所有40个数据后会拉低一段时间作为结束
													//捕捉到上升沿且接收数据个数为40				
				next_state = WAIT_2S;					//状态跳转到WAIT_2S，重新开始新一轮采集
			else 	
				next_state = REV_data;				//条件不满足状态不变
		end	
		default:next_state = WAIT_2S;					//默认状态为WAIT_2S
	endcase
end	
 
//状态机第三段：时序逻辑描述输出
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)begin										//复位状态下输出如下						
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
				dht22_en <= 1'b0;						//释放总线，由外部电阻拉高
				if(cnt_us == T_2S)						
					cnt_us <= 22'd0;					//计时满足条件则清零
				else
				begin
				   cnt_us <= cnt_us + 1'd1;			    //计时不满足条件则继续计时
				   if(cnt_us % 125000 == 0)              //每各12.5ms进度条加一
				      if(cnt_us == 125000)
					    progress_bar <= 16'b1000000000000000;
					  else
				        progress_bar <= progress_bar >>> 1;
				end
					
			end
			START		:begin
				dht22_en <= 1'b1;						//占用总线
				dht22_out <= 1'b0;						//输出低电平
				if(cnt_us == T_BE)		
					cnt_us <= 22'd0;					//计时满足条件则清零
				else		
					cnt_us <= cnt_us + 1'd1;			//计时不满足条件则继续计时
			end		
			DELAY_30us	:begin		
				dht22_en <= 1'b0;						//释放总线，由外部电阻拉高
				if(cnt_us == T_GO || dht22_fall)
					cnt_us <= 22'd0;					//计时满足条件则清零
				else                                    
					cnt_us <= cnt_us + 1'd1;            //计时不满足条件则继续计时
			end	
			REPLY		:begin
				dht22_en <= 1'b0;						//释放总线，由外部电阻拉高
				if(cnt_us <= 'd500)begin				//计时不到500us
                    if(dht22_rise)                      //上升沿响应
						cnt_us <= 22'd0;				//计时清零
					else
						cnt_us <= cnt_us + 1'd1;		//计时不满足条件则继续计时
				end
				else 
					cnt_us <= 22'd0;					//超过500us仍没有上升沿响应，则计数清零 
			end	
			DELAY_75us  :begin
				dht22_en <= 1'b0;						//释放总线，由外部电阻拉高
				if(dht22_fall)                          //下降沿响应
				    begin
					cnt_us <= 22'd0;					//计时清零
					bit_cnt <=  6'd0; 					//清空数据接收计数器
					end
				else 	
					cnt_us <= cnt_us + 1'd1;			//计时不满足条件则继续计时
			end
			REV_data	:begin
				dht22_en <= 1'b0;						//释放总线，由外部电阻拉高，进入读取状态
				if(bit_cnt >= 'd40)begin	            //数据接收完毕
					cnt_us <= 22'd0;					//清空计时器
				end
				else if(dht22_fall)begin				//检测到低电平，则说明接收到一个数据
					bit_cnt <= bit_cnt + 1'd1;			//数据接收计数器+1
					cnt_us <= 22'd0;					//计时器重新计数
					if(cnt_us <= 'd100)					
						data_temp[39-bit_cnt] <= 1'b0;	//总共所有的时间少于100us,则说明接收到"0"
					else 
						data_temp[39-bit_cnt] <= 1'b1;	//总共所有的时间大于100us,则说明接收到"1"
				end
				else begin								//所有数据没有接收完，且正处于1个数据的接收进程中
					bit_cnt <= bit_cnt;				
					data_temp <= data_temp;
					cnt_us <= cnt_us + 1'd1;			//计时器计时
				end
			end
			
			default:;		
		endcase
end
 
//校验读取的数据是否符合校验规则
always @(posedge clk_us or negedge rst_n)begin
	if(!rst_n)
		data_valid <= 32'd0;
	else if((data_temp[7:0] == data_temp[39:32] + data_temp[31:24] +
	data_temp[23:16] + data_temp[15:8]))
		data_valid <= data_temp[39:8]; 		//符合规则，则把有效数据赋值给输出
	else
		data_valid <= data_valid;			//不符合规则，则舍弃这次读取的数据，输出仍保持上次的状态不变
end
		
endmodule

