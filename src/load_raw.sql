
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
.import players__East_Berks_Football_Alliance__ByTeam-FAN_Pending-Denied.csv raw_players_fan_pending_denied
.import players__East_Berks_Football_Alliance__EBFA-No_24-25_GS-LPGAF.csv raw_players_no_lpgaf
.import players__East_Berks_Football_Alliance__PL01.1_Photo_NOT_Loaded.csv raw_players_no_photo
.import players__East_Berks_Football_Alliance__ByTeam-No_POA_Uploaded.csv raw_players_no_poa
.import players__East_Berks_Football_Alliance__PL02.1_POA_NOT_Vertified.csv raw_players_poa_not_verified

/* note that the tables will actually named raw.coaches and so on */