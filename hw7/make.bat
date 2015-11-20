copy U:\eecs51\hw7test.obj .
asm86chk hw7main.asm
asm86 hw7main.asm m1 ep db
asm86chk serial.asm
asm86 serial.asm m1 ep db
asm86 init.asm m1 ep db
asm86 queue.asm m1 ep db
asm86 initSeri.asm m1 ep db
link86 hw7main.obj, serial.obj, init.obj, queue.obj, initSeri.obj, hw7test.obj to hw7main.lnk
loc86 hw7main.lnk to hw7main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug
