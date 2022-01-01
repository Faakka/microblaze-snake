#include <xparameters.h>
#include <xaxidma_hw.h>
#include <mb_interface.h>
#include <xil_types.h>
#include <xintc_l.h>
#include <stdlib.h>

#define RED 0x000000FF
#define GREEN 0x0000FF00
#define BLUE 0x00FF0000
#define FOOD 0x00008CFF
#define SNAKE 0x00228B22
#define WALL 0x00A9A9A9
#define BACKGROUND 0x00000000

#define MAX_LEVEL 8
#define MAX_SCORE 20
#define INITIAL_SPEED 10
#define MAX_SPEED 2
#define INITIAL_SIZE 10
#define SPEED_UP 1

#define BTN_STATUS_REG				0x00
#define BTN_IE_REG					0x04
#define BTN_IF_REG					0x08

#define BTN0_IRQ				0x1
#define BTN1_IRQ				0x2
#define BTN2_IRQ				0x4
#define BTN3_IRQ				0x8

//*****************************************************************************
//* Makrók a memória írásához és olvasásához.                                 *
//*****************************************************************************
#define MEM8(addr)   (*(volatile unsigned char *)(addr))
#define MEM16(addr)  (*(volatile unsigned short *)(addr))
#define MEM32(addr)  (*(volatile unsigned long *)(addr))

void btn_int_handler(void *instancePtr);
void dma_int_handler(void *instancePtr);
void dma_init(unsigned long baseaddr);
void dma_mm2s_start(unsigned long baseaddr, void *src, unsigned long length);
void draw_rect(unsigned char row, unsigned char column, unsigned long color);
void init_game(void);
void move_snake(void);
void change_dir(void);
uint8_t check_death(void);
void generate_food(void);
void eat_food(void);
void display_score(void);

unsigned long dma_vram[480][640] __attribute__((aligned(128), section(".extmem")));
//unsigned long *vram_ptr = 0x80000000;

enum direction{LEFT, DOWN, UP, RIGHT};
enum direction new_dir;

uint8_t snake_size;

uint8_t speed;
uint8_t tick_cntr = 0;
uint8_t move = 0;

struct Part{
	uint16_t row;
	uint16_t col;
	enum direction dir;
};

struct Part food;
struct Part snake[INITIAL_SIZE+MAX_SCORE];

uint8_t score;
uint8_t level;
uint8_t game_over;

uint8_t seg_num;
const uint8_t seven_seg_lut[] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

void btn_int_handler(void *instancePtr)
{
	unsigned char ifr;

	// Interrupt flag regiszter kiolvasása
	ifr = MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG);

	// Lenyomott gomb (irány) megállapítása
	if(ifr & BTN0_IRQ)
		new_dir = RIGHT;
	else if(ifr & BTN1_IRQ)
		new_dir = UP;
	else if(ifr & BTN2_IRQ)
		new_dir = DOWN;
	else
		new_dir = LEFT;

	change_dir();

	// Interrupt flag regiszter törlése
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = ifr;
}

void dma_int_handler(void *instancePtr) {

	if(tick_cntr != speed) {
		tick_cntr++;
	}
	else {
		tick_cntr = 0;
		move = 1;
	}

	uint32_t status = MEM32(XPAR_AXIDMA_0_BASEADDR + + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET);
	MEM32(XPAR_AXIDMA_0_BASEADDR + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET) = status;

	microblaze_flush_dcache();
	dma_mm2s_start(XPAR_AXIDMA_0_BASEADDR, dma_vram, 640*480*4);
}


//*****************************************************************************
//* Az AXI DMA perifériát kezelõ fügvények.                                   *
//*****************************************************************************
void dma_init(unsigned long baseaddr)
{
	// MM2S
	// Control Register (CR): RUNSTOP (start DMA ops) | Interrupt on Complete (IoC) enable
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_CR_OFFSET)) = XAXIDMA_CR_RUNSTOP_MASK | XAXIDMA_IRQ_IOC_MASK;

	// IoC interrupt flag törlés
	uint32_t status = MEM32(XPAR_AXIDMA_0_BASEADDR + + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET);
	MEM32(XPAR_AXIDMA_0_BASEADDR + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET) = status;
}

void dma_mm2s_start(unsigned long baseaddr, void *src, unsigned long length)
{
	//A forráscím beállítása. A felsõ 32 bit mindig 0.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_OFFSET)) = (unsigned long)src;
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_SRCADDR_MSB_OFFSET)) = 0;
	//Az adatméret beállítása, ennek hatására indul az MM2S DMA átvitel.
	MEM32(baseaddr + (XAXIDMA_TX_OFFSET + XAXIDMA_BUFFLEN_OFFSET)) = length;
}

void draw_rect(unsigned char row, unsigned char column, unsigned long color) {

	uint16_t base_row = 10 * row;
	uint16_t base_col = 10 * column;
	uint8_t i, j;

	for(i = 0; i < 10; i++) {
		for(j = 0; j < 10; j++) {
			dma_vram[base_row+i][base_col+j] = color;
		}
	}
}

void init_game(void) {

	uint8_t i, j;

	for(i = 0; i < 48; i++) {
		for(j = 0; j < 64; j++) {
			if(i == 0 || i == 47 || j == 0 || j == 63)
				draw_rect(i, j, WALL);
			else
				draw_rect(i, j, BACKGROUND);
		}
	}

	snake_size = INITIAL_SIZE;
	speed = INITIAL_SPEED;
	level = 1;
	score = 0;

	for(i = 0; i < INITIAL_SIZE; i++) {
		snake[i].row = 23;
		snake[i].col = 31+i;
		snake[i].dir = LEFT;
	}

	generate_food();
	game_over = 0;
	MEM32(XPAR_GPIO_LED_BASEADDR) = 0x01;
}

void move_snake(void) {

	// a legutolso bodypart torlese
	draw_rect(snake[snake_size-1].row, snake[snake_size-1].col, BACKGROUND);

	// a fej kirajozolasa az irany szerint
	if(snake[0].dir == LEFT) {
		snake[0].col--;
		draw_rect(snake[0].row, snake[0].col, SNAKE);
	} else if(snake[0].dir == DOWN) {
		snake[0].row++;
		draw_rect(snake[0].row, snake[0].col, SNAKE);
	} else if(snake[0].dir == UP) {
		snake[0].row--;
		draw_rect(snake[0].row, snake[0].col, SNAKE);
	} else {
		snake[0].col++;
		draw_rect(snake[0].row, snake[0].col, SNAKE);
	}

	uint8_t i;
	// a tobbi testresz kirajzolasa iranyuk szerint
	for(i = snake_size - 1; i > 0; i--) {
		if(snake[i].dir == LEFT)
			snake[i].col--;
		else if(snake[i].dir == DOWN)
			snake[i].row++;
		else if(snake[i].dir == UP)
			snake[i].row--;
		else
			snake[i].col++;

		draw_rect(snake[i].row, snake[i].col, SNAKE);
		// minden testresz koveti az elotte levo iranyat
		snake[i].dir = snake[i-1].dir;
	}

	move = 0;
}

void change_dir(void) {

	if(((snake[0].dir == LEFT || snake[0].dir == RIGHT) && (new_dir == UP || new_dir == DOWN)) ||
					((snake[0].dir == DOWN || snake[0].dir == UP) && (new_dir == LEFT || new_dir == RIGHT))) {
		snake[0].dir = new_dir;
	}
}

uint8_t check_death(void) {
	if(snake[0].row == 0 || snake[0].row == 47 || snake[0].col == 0 || snake[0].col == 63) {
		return 1;
	} else {
		uint8_t i;
		for(i = 1; i < snake_size-1; i++) {
			if((snake[0].row == snake[i].row) && (snake[0].col == snake[i].col)) {
				return 1;
			}
		}
	}

	return 0;
}

void generate_food(void) {
	uint8_t rand_row, rand_col, i;

	uint8_t is_placement_ok = 0;

	while(!is_placement_ok) {
		is_placement_ok = 1;
		rand_row = rand() % 47;
		rand_col = rand() % 63;
		if(rand_row != 0 && rand_col != 0) {
			for(i = 0; i < snake_size-1; i++) {
				if(snake[i].row == rand_row && snake[i].col == rand_col)
					is_placement_ok = 0;
			}
		} else {
			is_placement_ok = 0;
		}
	}

	food.row = rand_row;
	food.col = rand_col;
	draw_rect(food.row, food.col, FOOD);
}

void eat_food(void) {
	if(food.row == snake[0].row && food.col == snake[0].col) {
		draw_rect(food.row, food.col, SNAKE);
		snake[snake_size].dir = snake[snake_size-1].dir;
		if(snake[snake_size].dir == LEFT) {
			snake[snake_size].row = snake[snake_size-1].row;
			snake[snake_size].col = snake[snake_size-1].col+1;
		} else if(snake[snake_size].dir == DOWN) {
			snake[snake_size].row = snake[snake_size-1].row-1;
			snake[snake_size].col = snake[snake_size-1].col;
		} else if(snake[snake_size].dir == UP) {
			snake[snake_size].row = snake[snake_size-1].row+1;
			snake[snake_size].col = snake[snake_size-1].col;
		} else {
			snake[snake_size].row = snake[snake_size-1].row;
			snake[snake_size].col = snake[snake_size-1].col-1;
		}
		snake_size++;

		if(score < MAX_SCORE-1) {
			score++;
		} else {
			score = 0;
			uint8_t i;
			for(i = INITIAL_SIZE; i < snake_size-1; i++)
				draw_rect(snake[i].row, snake[i].col, BACKGROUND);

			snake_size = INITIAL_SIZE;

			if(level == MAX_LEVEL) {
				game_over = 1;
			} else {
				level++;
				uint8_t led = MEM32(XPAR_GPIO_LED_BASEADDR);
				MEM32(XPAR_GPIO_LED_BASEADDR) = ((led << 1) + 1);
				if((speed - SPEED_UP) >= MAX_SPEED)
					speed = speed - SPEED_UP;
			}
		}

		if(!game_over)
			generate_food();
	}
}

void display_score(void) {

	uint8_t tens = score / 10;

	if(seg_num == 0) {
		MEM32(XPAR_GPIO_7SEG_BASEADDR) = (0x00000100 | seven_seg_lut[score-10*tens]);
		seg_num++;
	} else {
		MEM32(XPAR_GPIO_7SEG_BASEADDR) = (0x00000200 | seven_seg_lut[tens]);
		seg_num--;
	}

	// kis kesleltetes, hogy a szegmensek ertekei ne csusszanak ossze
	volatile uint16_t i;
	for(i = 0; i < 8000; i++);
}

int main()
{

	microblaze_enable_dcache();

	//A megszakításkezelõ rutin regisztrálása.
	//XIntc_RegisterHandler()
	XIntc_RegisterHandler(
			XPAR_INTC_0_BASEADDR,
			XPAR_AXI_INTC_0_AXI4_LITE_BTN_0_IRQ_INTR,
			(XInterruptHandler) btn_int_handler,
			NULL);

	XIntc_RegisterHandler(
			XPAR_INTC_0_BASEADDR,
			XPAR_AXI_INTC_0_AXI_DMA_0_MM2S_INTROUT_INTR,
			(XInterruptHandler) dma_int_handler,
			NULL);

	//A használt megszakítások engedélyezése a megszakítás vezérlõben.
	XIntc_MasterEnable(XPAR_INTC_0_BASEADDR);
	XIntc_EnableIntr(XPAR_INTC_0_BASEADDR, XPAR_AXI4_LITE_BTN_0_IRQ_MASK | XPAR_AXI_DMA_0_MM2S_INTROUT_MASK);

	//A megszakítás engedélyezése a btn perifériában:
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = 0x0000000F;
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IE_REG) = 0x0000000F;

	//A megszakítások engedélyezése a MicroBlaze processzoron.
	microblaze_enable_interrupts();

	//Az AXI DMA vezérlõ inicializálása.
	dma_init(XPAR_AXIDMA_0_BASEADDR);

	init_game();

	microblaze_flush_dcache();
	dma_mm2s_start(XPAR_AXIDMA_0_BASEADDR, dma_vram, 640*480*4);

	for (;;) {
		if(game_over)
			init_game();
		if(move) {
			move_snake();
			game_over = check_death();
			eat_food();
		}

		display_score();
	}

	return 0;
}
