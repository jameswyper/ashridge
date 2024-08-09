
drop table if exists raw_coaches;
drop table if exists raw_teams;
drop table if exists raw_managers;
drop table if exists raw_players_all;
drop table if exists raw_players_fan_pending_denied;
drop table if exists raw_players_no_lpgaf;
drop table if exists raw_players_no_photo;
drop table if exists raw_players_no_poa;
drop table if exists raw_players_poa_not_verified;

.mode csv
.import coaches.csv raw_coaches
.import managers.csv raw_managers
.import teams_all.csv raw_teams
.import players_all.csv raw_players_all
.import players__East_Berks_Football_Alliance__PL01.1_ByTeam-FAN_Pending-Denied_-_CL.csv raw_players_fan_pending_denied
.import players__East_Berks_Football_Alliance__PL01.5_ByTeam-No_24-25_GS-LPGAF_-_CL.csv raw_players_no_lpgaf
.import players__East_Berks_Football_Alliance__PL02.2_Photo_NOT_Loaded_-_CL.csv raw_players_no_photo
.import players__East_Berks_Football_Alliance__PL01.3_ByTeam-No_POA_Uploaded_-_CL.csv  raw_players_no_poa
.import players__East_Berks_Football_Alliance__PL02.4_EBFA-POA_NOT_Vertified_-_CL.csv raw_players_poa_not_verified

/* note that the tables will actually named raw.coaches and so on */