-- create smaller versions of the players and teams tables from gs with nicer column names and load them

drop table if exists gs_stg_players_all;
drop table if exists gs_teams_all;

create table gs_stg_players_all (first_name,last_name,gender,birthdate,email,address,postal_code,id,
parent_one_first_name,parent_one_last_name,parent_one_email,parent_two_first_name,parent_two_last_name,parent_two_email,
team_id,team,team_age,team_gender);

create table gs_teams_all (team_id,team,gender,age,level,club_id,club,players,agesort);

insert into gs_stg_players_all(first_name,last_name,gender,birthdate,email,address,postal_code,id,
parent_one_first_name,parent_one_last_name,parent_one_email,parent_two_first_name,parent_two_last_name,parent_two_email,
team_id,team,team_age,team_gender)
select "First Name" , "Last Name" , "Gender" , "Birthdate" , "Email", "Address",  "Postal Code", "Id Number",
 "Parent One First Name", "Parent One Last Name" , "Parent One Email", 
 "Parent Two First Name" , "Parent Two Last Name" , "Parent Two Email",
  "Team" , 
  case when "Team Name" = '' then null else "Team Name" end, 
  "Team Age" , "Team Gender"
 from "raw_players_all";

 insert into gs_teams_all (team_id,team,gender,age,level,club_id,club,players,agesort)
 select "Team ID", "Team", "Gender", "Age" ,
 "Level" , "Club ID" , "Club" ,  "Players" ,
 case when length("Age") == 2 then '0'|| ltrim("Age",'U') else ltrim("Age",'U') end 
 from "raw_teams";

-- do the same with the saved search tables

drop table if exists gs_stg_players_no_lpgaf;
drop table if exists gs_stg_players_no_fan;
drop table if exists gs_stg_players_no_poa;
drop table if exists gs_stg_players_no_photo;
drop table if exists gs_stg_players_poa_not_verified;

create table gs_stg_players_no_lpgaf (first_name,last_name,birthdate,id);
create table gs_stg_players_no_fan (first_name,last_name,birthdate,id);
create table gs_stg_players_no_poa (first_name,last_name,birthdate,id);
create table gs_stg_players_no_photo (first_name,last_name,birthdate,id);
create table gs_stg_players_poa_not_verified (first_name,last_name,birthdate,id);

insert into gs_stg_players_no_fan (first_name,last_name,birthdate,id) select "First Name", "Last Name", "Birthdate", "Id Number" from raw_players_fan_pending_denied;
insert into gs_stg_players_no_lpgaf (first_name,last_name,birthdate,id) select "First Name", "Last Name", "Birthdate", "Id Number" from raw_players_no_lpgaf;
insert into gs_stg_players_no_photo (first_name,last_name,birthdate,id) select "First Name", "Last Name", "Birthdate", "Id Number" from raw_players_no_photo;
insert into gs_stg_players_no_poa (first_name,last_name,birthdate,id) select "First Name", "Last Name", "Birthdate", "Id Number" from raw_players_no_poa;
insert into gs_stg_players_poa_not_verified (first_name,last_name,birthdate,id) select "First Name", "Last Name", "Birthdate", "Id Number" from raw_players_poa_not_verified;

-- use left outer joins to convert the saved search data into flags on the main table

drop table if exists gs_players_all;

create table gs_players_all as select a.*,
case when b.id is null then 'Y' else 'N' end as has_fan,
case when c.id is null then 'Y' else 'N' end as has_lpgaf,
case when d.id is null then 'Y' else 'N' end as has_photo,
case when e.id is null then 'Y' else 'N' end as has_poa,
case when f.id is null then 'Y' else 'N' end as has_verified_poa
from gs_stg_players_all a 
left join gs_stg_players_no_fan b on a.id = b.id 
left join gs_stg_players_no_lpgaf c on a.id = c.id
left join gs_stg_players_no_photo d on a.id = d.id
left join gs_stg_players_no_poa e on a.id = e.id
left join gs_stg_players_poa_not_verified f on a.id = f.id;

drop table if exists wg_players_all;

create table wg_players_all (first_name,last_name,fan,birthdate,age_group,gender,team,sub_date,reg_date,reg_status,player_email,parent_email,consent,over_16,over_14);

insert into wg_players_all (first_name,last_name,fan,birthdate,age_group,gender,team,sub_date,reg_date,reg_status,player_email,parent_email,consent,over_16,over_14)
select replace("First Names","'",''),replace("Surname","'",''),replace("FAN ID","'",''),
replace("Date of birth","'",''),replace("Age Group","'",''),
case when replace("Gender","'",'') == 'Male' then 'm' when replace("Gender","'",'') == 'Female' then 'f' else 'u' end,
replace("Team","'",''), replace("Date Submitted","'",''),replace("Date Registered","'",''),
replace("Registration Status","'",''), 
replace("Email Address","'",''), replace("Parent/carer email address","'",''),replace("Consent Given","'",''),
case when replace("Date of Birth","'",'') < date('now','-16 years') = 1 then 'Y' else 'N' end,
case when replace("Date of Birth","'",'') < date('now','-14 years') = 1 then 'Y' else 'N' end
from raw_wgreg;

drop table if exists stg_gs_fan_etc;
create table stg_gs_fan_etc as select first_name, last_name, birthdate, country_birth, country_citizen, fan, 
case when fanlocked = 'true' then 'Y' else 'N' end as fan_locked,
case when namelocked = 'true' then 'Y' else 'N' end as name_locked
from raw_gs_fan_etc;




-- join gs FAN to gs players on first/last/dob
-- outer join gs to wg on first/last/dob
-- add indicators for not on wg / not on gs

drop view if exists stg_player_match;

create view stg_player_match as select 
w.fan as fan,
w.last_name as wg_last_name,
w.first_name as wg_first_name,
w.birthdate as wg_birthdate,
w.team wg_team,
g.id as id,
g.last_name as gs_last_name,
g.first_name as gs_first_name,
g.birthdate as gs_birthdate,
g.team as gs_team,
w.sub_date as wg_sub_date,w.reg_date as wg_reg_date,w.reg_status as wg_reg_status,
w.player_email as wg_player_email,w.parent_email as wg_parent_email,w.consent as wg_consent,w.over_16 as over_16,w.over_14 as over_14
from wg_players_all w full outer join gs_players_all g
on trim(lower(w.last_name)) = trim(lower(g.last_name))
and trim(lower(w.first_name)) = trim(lower(g.first_name))
and w.birthdate = g.birthdate;

drop view if exists player_match;
create view player_match  as 
select
coalesce(gs_last_name,wg_last_name) as last_name,
coalesce(gs_first_name,wg_first_name) as first_name,
case when a.id is null then 'N' else 'Y' end as on_gotsport,
case when a.fan is null then 'N' else 'Y' end as on_wholegame,
a.fan as wg_fan,
gf.fan as gs_fan, 
coalesce(gs_team,wg_team) as team,
gs_team,
wg_team,
t.agesort,
has_fan,
has_lpgaf,
has_photo,
has_poa,
has_verified_poa,
wg_sub_date, wg_reg_date, wg_reg_status,  wg_player_email, wg_parent_email, wg_consent, over_16, over_14,
g.postal_code as postcode, g.address as address, gs_birthdate, wg_birthdate
from
stg_player_match a left outer join gs_players_all g on a.id = g.id
 left outer join gs_teams_all t on coalesce(gs_team,wg_team) = t.team
 left outer join stg_gs_fan_etc gf on gs_first_name = gf.first_name and gs_last_name = gf.last_name and gs_birthdate = gf.birthdate;



-- reports:  more than one team for a player
--           on wg not gs
--           registration progress
--           needs FAN on wg
--           needs consent on wg
