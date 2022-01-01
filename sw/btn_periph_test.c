#include <xparameters.h>
#include <xintc_l.h>
#include <mb_interface.h>


//*****************************************************************************
//* Makr�k a mem�ria �r�s�hoz �s olvas�s�hoz.                                 *
//*****************************************************************************
#define MEM8(addr)   (*(volatile unsigned char *)(addr))
#define MEM16(addr)  (*(volatile unsigned short *)(addr))
#define MEM32(addr)  (*(volatile unsigned long *)(addr))


//*****************************************************************************
//* Defin�ci�k a folyad�kszint jelz� perif�ri�hoz.                            *
//*****************************************************************************
//St�tusz regiszter: 32 bites, csak olvashat�
#define BTN_STATUS_REG				0x00
//Megszak�t�s enged�lyez� regiszter: 32 bites, �rhat�/olvashat�
#define BTN_IE_REG					0x04
//Megszak�t�s flag regiszter: 32 bites, olvashat�  �s '1' be�r�ssal t�r�lhet�
#define BTN_IF_REG					0x08

//A folyad�kszint jelz� perif�ria megszak�t�s esem�nyei.
#define BTN0_IRQ				(1 << 0)
#define BTN1_IRQ				(1 << 1)
#define BTN2_IRQ				(1 << 2)
#define BTN3_IRQ				(1 << 3)


//*****************************************************************************
//* A nyom�gomb perif�ria megszak�t�skezel� rutinja.              *
//*****************************************************************************
void btn_int_handler(void *instancePtr)
{
	unsigned char ifr;

	// Interrupt flag regiszter kiolvas�sa
	ifr = MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG);

	// Lenyomott gomb (ir�ny) meg�llap�t�sa
	if(ifr & BTN0_IRQ)
		xil_printf("RIGHT\n");
	else if(ifr & BTN1_IRQ)
		xil_printf("UP\n");
	else if(ifr & BTN2_IRQ)
			xil_printf("DOWN\n");
	else if(ifr & BTN3_IRQ)
			xil_printf("LEFT\n");

	// Interrupt flag regiszter t�rl�se
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = ifr;
}


//*****************************************************************************
//* F�program.                                                                *
//*****************************************************************************
int main()
{

	//A megszak�t�skezel� rutin regisztr�l�sa.
	//XIntc_RegisterHandler()
	XIntc_RegisterHandler(
			XPAR_INTC_0_BASEADDR,
			XPAR_AXI_INTC_0_AXI4_LITE_BTN_0_IRQ_INTR,
			(XInterruptHandler) btn_int_handler,
			NULL);


	//A haszn�lt megszak�t�sok enged�lyez�se a megszak�t�s vez�rl�ben.
	//XIntc_MasterEnable()
	//XIntc_EnableIntr()
	XIntc_MasterEnable(XPAR_INTC_0_BASEADDR);
	XIntc_EnableIntr(XPAR_INTC_0_BASEADDR, XPAR_AXI4_LITE_BTN_0_IRQ_MASK);

	//A megszak�t�s enged�lyez�se a btn perif�ri�ban:
	//ERROR flag t�rl�se, ERROR megszak�t�s enged�lyez�se.
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IF_REG) = (BTN0_IRQ | BTN1_IRQ | BTN2_IRQ | BTN3_IRQ);
	MEM32(XPAR_AXI4_LITE_BTN_0_BASEADDR + BTN_IE_REG) = (BTN0_IRQ | BTN1_IRQ | BTN2_IRQ | BTN3_IRQ);

	//A megszak�t�sok enged�lyez�se a MicroBlaze processzoron.
	//microblaze_enable_interrupts()
	microblaze_enable_interrupts();

	for (;;)
	{
	}

	return 0;
}
