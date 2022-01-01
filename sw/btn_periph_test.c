#include <xparameters.h>
#include <xintc_l.h>
#include <mb_interface.h>


//*****************************************************************************
//* Makrók a memória írásához és olvasásához.                                 *
//*****************************************************************************
#define MEM8(addr)   (*(volatile unsigned char *)(addr))
#define MEM16(addr)  (*(volatile unsigned short *)(addr))
#define MEM32(addr)  (*(volatile unsigned long *)(addr))


//*****************************************************************************
//* Definíciók a folyadékszint jelzõ perifériához.                            *
//*****************************************************************************
//Státusz regiszter: 32 bites, csak olvasható
#define BTN_STATUS_REG				0x00
//Megszakítás engedélyezõ regiszter: 32 bites, írható/olvasható
#define BTN_IE_REG					0x04
//Megszakítás flag regiszter: 32 bites, olvasható  és '1' beírással törölhetõ
#define BTN_IF_REG					0x08

//A folyadékszint jelzõ periféria megszakítás eseményei.
#define BTN0_IRQ				(1 << 0)
#define BTN1_IRQ				(1 << 1)
#define BTN2_IRQ				(1 << 2)
#define BTN3_IRQ				(1 << 3)


//*****************************************************************************
//* A nyomógomb periféria megszakításkezelõ rutinja.              *
//*****************************************************************************
void btn_int_handler(void *instancePtr)
{
	unsigned char ifr;

	// Interrupt flag regiszter kiolvasása
	ifr = MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG);

	// Lenyomott gomb (irány) megállapítása
	if(ifr & BTN0_IRQ)
		xil_printf("RIGHT\n");
	else if(ifr & BTN1_IRQ)
		xil_printf("UP\n");
	else if(ifr & BTN2_IRQ)
			xil_printf("DOWN\n");
	else if(ifr & BTN3_IRQ)
			xil_printf("LEFT\n");

	// Interrupt flag regiszter törlése
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = ifr;
}


//*****************************************************************************
//* Fõprogram.                                                                *
//*****************************************************************************
int main()
{

	//A megszakításkezelõ rutin regisztrálása.
	//XIntc_RegisterHandler()
	XIntc_RegisterHandler(
			XPAR_INTC_0_BASEADDR,
			XPAR_AXI_INTC_0_AXI4_LITE_BTN_0_IRQ_INTR,
			(XInterruptHandler) btn_int_handler,
			NULL);


	//A használt megszakítások engedélyezése a megszakítás vezérlõben.
	//XIntc_MasterEnable()
	//XIntc_EnableIntr()
	XIntc_MasterEnable(XPAR_INTC_0_BASEADDR);
	XIntc_EnableIntr(XPAR_INTC_0_BASEADDR, XPAR_AXI4_LITE_BTN_0_IRQ_MASK);

	//A megszakítás engedélyezése a btn perifériában:
	//ERROR flag törlése, ERROR megszakítás engedélyezése.
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = (BTN0_IRQ | BTN1_IRQ | BTN2_IRQ | BTN3_IRQ);
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IE_REG) = (BTN0_IRQ | BTN1_IRQ | BTN2_IRQ | BTN3_IRQ);

	//A megszakítások engedélyezése a MicroBlaze processzoron.
	//microblaze_enable_interrupts()
	microblaze_enable_interrupts();

	for (;;)
	{
	}

	return 0;
}
