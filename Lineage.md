A brief guide to which tables are used where

raw_ tables are almost all loaded directly from external sources (CSV or XLS files, or gs_get_fan*.rb) in the load_*.sql files

The only exception is raw_gs_fan_etc which, ONLY if you are running in the undocumented parallel road, is created from raw_gs_fan_etcX where X ranges between 1 and 4 (in parallel.sql)

staging.sql

raw_players_all -> gs_stg_players_all
raw_teams_all -> gs_teams_all

raw_players_fan_pending_denied -> gs_stg_players_no_fan
raw_players_no_lpgaf -> gs_stg_players_no_lpgaf
raw_players_no_photo -> gs_stg_players_no_photo
raw_players_no_poa -> gs_stg_players_no_poa
raw_players_poa_not_verified -> gs_stg_players_poa_not_verified
raw_wgreg -> wg_players_all
raw_gs_fan_etc -> stg_gs_fan_etc

gs_stg_players_all
gs_stg_players_no_fan
gs_stg_players_no_lpgaf
gs_stg_players_no_photo                -> gs_players_all
gs_stg_players_no_poa
gs_stg_players_poa_not_verified

wg_players_all
gs_players_all -> stg_player_match

stg_player_match
gs_players_all
gs_teams_all   -> player_match
stg_gs_fan_etc 