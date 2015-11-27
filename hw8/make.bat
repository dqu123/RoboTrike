copy U:\eecs51\hw8test.obj .
asm86chk hw8main.asm
asm86 hw8main.asm m1 ep db
asm86chk parser.asm
asm86 parser.asm m1 ep db
link86 hw8main.obj, parser.obj, hw8test.obj to hw8main.lnk
loc86 hw8main.lnk to hw8main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug
