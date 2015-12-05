asm86chk motorMn.asm
asm86 motorMn.asm m1 ep db
asm86 init.asm m1 ep db
asm86 events.asm m1 ep db
asm86 motor.asm m1 ep db
asm86 motorTmr.asm m1 ep db
asm86 trigTbl.asm m1 ep db
asm86 converts.asm m1 ep db
asm86 serial.asm m1 ep db
asm86 queue.asm m1 ep db
asm86 parser.asm m1 ep db
asm86 initSeri.asm m1 ep db
asm86 general.asm m1 ep db
link86 motorMn.obj, init.obj, motor.obj, motorTmr.obj, trigTbl.obj, general.obj to link1.lnk
link86 converts.obj, serial.obj, queue.obj, initSeri.obj, events.obj, parser.obj to link2.lnk
link86 link1.lnk, link2.lnk to motorMn.lnk
loc86 motorMn.lnk to motorMn.exe NOIC AD(SM(CODE(4000H),DATA(400H),STACK(7000H)))
pcdebug -p COM3
