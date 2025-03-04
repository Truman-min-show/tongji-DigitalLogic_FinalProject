module main(
    input CLK,
    input rst,
    output [7:0] DISPLAY_sel,
    output [7:0] DISPLAY_seg,
    output signed [15:0] led,
    inout DHT22
    );
    wire [31:0]temperature;
    dht22_drive my_dht22(CLK,!rst,DHT22,temperature,led);
    display my_display(CLK,!rst,temperature[15:0],DISPLAY_sel,DISPLAY_seg);
endmodule
