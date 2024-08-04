ATTACH DATABASE ./parallel/report1.db AS r1;
ATTACH DATABASE ./parallel/report2.db AS r2;
ATTACH DATABASE ./parallel/report3.db AS r3;
ATTACH DATABASE ./parallel/report4.db AS r4;
ATTACH DATABASE ./parallel/report5.db AS r5;
ATTACH DATABASE ./parallel/report6.db AS r6;
ATTACH DATABASE ./parallel/report7.db AS r7;
ATTACH DATABASE ./parallel/report8.db AS r8;

delete from raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r1.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r2.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r3.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r4.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r5.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r6.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r7.raw_gs_fan_etc;
insert into raw_gs_fan_etc select * from r8.raw_gs_fan_etc;