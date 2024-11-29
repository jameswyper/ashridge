
drop table if exists raw_coaches;

drop table if exists raw_managers;
drop table if exists raw_teams;
drop table if exists raw_managers_fan_photo;
drop table if exists raw_squad_mgr;
drop table if exists raw_squad_coach;


.mode csv
.import coaches.csv raw_coaches
.import managers.csv raw_managers
.import managers_fan_photo.csv raw_managers_fan_photo
.import teams_all.csv raw_teams
.import squadmgr.csv raw_squad_mgr
.import squadcoach.csv raw_squad_coach


/* note that the tables will actually named raw.coaches and so on */