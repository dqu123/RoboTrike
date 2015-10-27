asm86chk converts.asm
asm86 converts.asm m1 ep db
asm86 hw2test.asm m1 ep db
link86 hw2test.obj, converts.obj to hw2test.lnk
loc86 hw2test.lnk to hw2test.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
