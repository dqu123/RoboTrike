asm86chk remoteMn.asm
asm86 remoteMn.asm m1 ep db
asm86 events.asm m1 ep db
asm86 keypad.asm m1 ep db
asm86 init.asm m1 ep db
asm86 timer.asm m1 ep db
asm86 display.asm m1 ep db
asm86 converts.asm m1 ep db
asm86 segtab14.asm m1 ep db
asm86 serial.asm m1 ep db
asm86 queue.asm m1 ep db
asm86 initSeri.asm m1 ep db
asm86 general.asm m1 ep db
link86 remoteMn.obj, init.obj, keypad.obj, timer.obj, display.obj, events.obj to link1.lnk
link86 converts.obj, segtab14.obj, serial.obj, initSeri.obj, queue.obj, general.obj to link2.lnk 
link86 link1.lnk, link2.lnk to remoteMn.lnk
loc86 remoteMn.lnk to remoteMn.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug -p COM4
