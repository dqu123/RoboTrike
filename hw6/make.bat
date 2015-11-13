copy U:\eecs51\hw6test.obj .
asm86chk hw6main.asm
asm86 hw6main.asm m1 ep db
asm86chk motor.asm
asm86 motor.asm m1 ep db
asm86 init.asm m1 ep db
asm86 motorTmr.asm m1 ep db
asm86 trigTbl.asm m1 ep db
link86 hw6main.obj, motor.obj, init.obj, motorTmr.obj, trigTbl.obj, hw6test.obj to hw6main.lnk
loc86 hw6main.lnk to hw6main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug
