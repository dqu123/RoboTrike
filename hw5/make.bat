copy U:\eecs51\hw54test.obj .
asm86chk hw5main.asm
asm86 hw5main.asm m1 ep db
asm86chk keypad.asm
asm86 keypad.asm m1 ep db
asm86 init.asm m1 ep db
asm86 timer.asm m1 ep db
asm86 display.asm m1 ep db
asm86 converts.asm m1 ep db
asm86 segtab14.asm m1 ep db
link86 hw5main.obj, init.obj, keypad.obj, timer.obj, display.obj, converts.obj, segtab14.obj, hw54test.obj to hw5main.lnk
loc86 hw5main.lnk to hw5main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug
