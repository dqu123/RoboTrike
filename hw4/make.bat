copy U:\eecs51\hw4test.obj .
asm86chk initEH.asm
asm86 initEH.asm m1 ep db
asm86chk hw4main.asm
asm86 hw4main.asm m1 ep db
asm86chk converts.asm
asm86 converts.asm m1 ep db
asm86chk display.asm
asm86 display.asm m1 ep db
asm86 segtab14.asm m1 ep db
link86 hw4main.obj, initEH.obj, display.obj, converts.obj, hw4test.obj, segtab14.obj to hw4main.lnk
loc86 hw4main.lnk to hw4main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug