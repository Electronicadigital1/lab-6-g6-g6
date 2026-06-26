module lcd1602_text #(
    parameter NUM_COMMANDS     = 4,
    parameter NUM_DATA_ALL     = 32,
    parameter NUM_DATA_PERLINE = 16,
    parameter DATA_BITS        = 8,
    parameter COUNT_MAX        = 800000
)(
    input  clk,
    input  reset,
    input  ready_i,
    output reg rs,
    output reg rw,
    output     enable,
    output reg [DATA_BITS-1:0] data,
    input  [1:0] sw
);

    // Define los estados de la FSM
    localparam IDLE              = 3'b000;
    localparam CONFIG_CMD1       = 3'b001;
    localparam WR_STATIC_TEXT_1L = 3'b010;
    localparam CONFIG_CMD2       = 3'b011;
    localparam WR_STATIC_TEXT_2L = 3'b100;

    reg [2:0] fsm_state;
    reg [2:0] next_state;
    reg       clk_16ms;

    // Comandos de configuración para el LCD
    localparam CLEAR_DISPLAY             = 8'h01;
    localparam SHIFT_CURSOR_RIGHT        = 8'h06;
    localparam DISPON_CURSOROFF          = 8'h0C;
    localparam LINES2_MATRIX5x8_MODE8bit = 8'h38;
    localparam START_2LINE               = 8'hC0;

    reg [$clog2(COUNT_MAX)-1:0]      clk_counter;
    reg [$clog2(NUM_COMMANDS):0]     command_counter;
    reg [$clog2(NUM_DATA_PERLINE):0] data_counter;

    // Memorias para texto y comandos
    reg [DATA_BITS-1:0] static_data_mem [0:NUM_DATA_ALL-1];
    reg [DATA_BITS-1:0] config_mem      [0:NUM_COMMANDS-1];

    // Mensajes fijos codificados en ASCII
    localparam [127:0] MSG1_L1 = {8'h20,8'h20,8'h20,8'h53,8'h69,8'h72,8'h76,8'h69,8'h65,8'h6E,8'h64,8'h6F,8'h20,8'h20,8'h20,8'h20};
    localparam [127:0] MSG1_L2 = {8'h20,8'h20,8'h20,8'h20,8'h43,8'h6F,8'h6D,8'h69,8'h64,8'h61,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};

    localparam [127:0] MSG2_L1 = {8'h20,8'h20,8'h20,8'h20,8'h46,8'h61,8'h6C,8'h74,8'h61,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};
    localparam [127:0] MSG2_L2 = {8'h20,8'h20,8'h20,8'h20,8'h43,8'h6F,8'h6D,8'h69,8'h64,8'h61,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};

    localparam [127:0] MSG3_L1 = {8'h20,8'h20,8'h20,8'h20,8'h20,8'h4D,8'h6F,8'h64,8'h6F,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};
    localparam [127:0] MSG3_L2 = {8'h20,8'h20,8'h20,8'h20,8'h4D,8'h61,8'h6E,8'h75,8'h61,8'h6C,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};

    localparam [127:0] MSG0_L1 = {8'h20,8'h20,8'h20,8'h20,8'h48,8'h6F,8'h72,8'h61,8'h3A,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20};
    localparam [127:0] MSG0_L2 = {8'h20,8'h20,8'h20,8'h20,8'h48,8'h48,8'h3A,8'h4D,8'h4D,8'h3A,8'h53,8'h53,8'h20,8'h20,8'h20,8'h20};

    reg [1:0] sw_prev;
    integer i;

    // Inicializa registros y carga mensaje por defecto
    initial begin
        fsm_state       <= IDLE;
        command_counter <= 'b0;
        data_counter    <= 'b0;
        rs              <= 1'b0;
        rw              <= 1'b0;
        data            <= 8'b0;
        clk_16ms        <= 1'b0;
        clk_counter     <= 'b0;
        sw_prev         <= 2'b00;

        config_mem[0] <= LINES2_MATRIX5x8_MODE8bit;
        config_mem[1] <= SHIFT_CURSOR_RIGHT;
        config_mem[2] <= DISPON_CURSOROFF;
        config_mem[3] <= CLEAR_DISPLAY;

        for (i = 0; i < 16; i = i + 1) begin
            static_data_mem[i]      = MSG0_L1[127 - i*8 -: 8];
            static_data_mem[16 + i] = MSG0_L2[127 - i*8 -: 8];
        end
    end

    // Genera el reloj lento clk_16ms
    always @(posedge clk) begin
        if (clk_counter == COUNT_MAX - 1) begin
            clk_16ms    <= ~clk_16ms;
            clk_counter <= 'b0;
        end else begin
            clk_counter <= clk_counter + 1;
        end
    end

    // Cambia el mensaje según el switch
    always @(posedge clk_16ms) begin
        if (reset == 0) begin
            sw_prev <= sw;
        end else begin
            if ((sw != sw_prev) && (fsm_state == IDLE)) begin
                sw_prev <= sw;
                case (sw)
                    2'b00: begin
                        for (i = 0; i < 16; i = i + 1) begin
                            static_data_mem[i]      <= MSG0_L1[127 - i*8 -: 8];
                            static_data_mem[16 + i] <= MSG0_L2[127 - i*8 -: 8];
                        end
                    end
                    2'b01: begin
                        for (i = 0; i < 16; i = i + 1) begin
                            static_data_mem[i]      <= MSG1_L1[127 - i*8 -: 8];
                            static_data_mem[16 + i] <= MSG1_L2[127 - i*8 -: 8];
                        end
                    end
                    2'b10: begin
                        for (i = 0; i < 16; i = i + 1) begin
                            static_data_mem[i]      <= MSG2_L1[127 - i*8 -: 8];
                            static_data_mem[16 + i] <= MSG2_L2[127 - i*8 -: 8];
                        end
                    end
                    2'b11: begin
                        for (i = 0; i < 16; i = i + 1) begin
                            static_data_mem[i]      <= MSG3_L1[127 - i*8 -: 8];
                            static_data_mem[16 + i] <= MSG3_L2[127 - i*8 -: 8];
                        end
                    end
                endcase
            end
        end
    end

    // Avanza la FSM o resetea a IDLE
    always @(posedge clk_16ms) begin
        if (reset == 0) begin
            fsm_state <= IDLE;
        end else begin
            fsm_state <= next_state;
        end
    end

    // Decide el siguiente estado de la FSM
    always @(*) begin
        case (fsm_state)
            IDLE: begin
                next_state = (ready_i) ? CONFIG_CMD1 : IDLE;
            end
            CONFIG_CMD1: begin
                next_state = (command_counter == NUM_COMMANDS) ? WR_STATIC_TEXT_1L : CONFIG_CMD1;
            end
            WR_STATIC_TEXT_1L: begin
                next_state = (data_counter == NUM_DATA_PERLINE) ? CONFIG_CMD2 : WR_STATIC_TEXT_1L;
            end
            CONFIG_CMD2: begin
                next_state = WR_STATIC_TEXT_2L;
            end
            WR_STATIC_TEXT_2L: begin
                next_state = (data_counter == NUM_DATA_PERLINE) ? IDLE : WR_STATIC_TEXT_2L;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Escribe comandos y datos según el estado
    always @(posedge clk_16ms) begin
        if (reset == 0) begin
            command_counter <= 'b0;
            data_counter    <= 'b0;
            data            <= 'b0;
        end else begin
            case (next_state)
                IDLE: begin
                    command_counter <= 'b0;
                    data_counter    <= 'b0;
                    rs              <= 1'b0;
                    data            <= 'b0;
                end
                CONFIG_CMD1: begin
                    rs              <= 1'b0;
                    command_counter <= command_counter + 1;
                    data            <= config_mem[command_counter];
                end
                WR_STATIC_TEXT_1L: begin
                    data_counter <= data_counter + 1;
                    rs           <= 1'b1;
                    data         <= static_data_mem[data_counter];
                end
                CONFIG_CMD2: begin
                    data_counter <= 'b0;
                    rs           <= 1'b0;
                    data         <= START_2LINE;
                end
                WR_STATIC_TEXT_2L: begin
                    data_counter <= data_counter + 1;
                    rs           <= 1'b1;
                    data         <= static_data_mem[NUM_DATA_PERLINE + data_counter];
                end
            endcase
        end
    end

    assign enable = clk_16ms;

endmodule