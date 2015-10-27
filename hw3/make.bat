copy U:\eecs51\hw3test.obj .
asm86chk queue.asm
asm86 queue.asm m1 ep db
asm86 hw3main.asm m1 ep db
link86 hw3main.obj, queue.obj, hw3test.obj to hw3main.lnk
loc86 hw3main.lnk to hw3main.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
