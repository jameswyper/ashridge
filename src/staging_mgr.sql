drop table if exists stg_mgr_wg;
drop table if exists stg_mgr_dbs;
drop table if exists stg_mgr_gs;
drop table if exists stg_mgr_1_gs;
drop table if exists stg_coach_gs;
drop table if exists stg_mgr_xl;
drop table if exists stg_team_xl;
drop table if exists stg_mgr_fan_photo;

create table stg_team_xl (team_name, team_age, training_time, training_day, training_venue);
insert into stg_team_xl (team_name, team_age, training_time, training_day, training_venue) 
  select replace("Team Name","'",''),cast("Team Age" as int), replace("Training Time","'",''),
  replace("Training Day","'",''),replace("Training Venue","'",'') from raw_ap_team where "Team Name" is not null;

create table stg_mgr_xl (team_name, role, name, email, fan, dob);
insert into stg_mgr_xl (team_name, role, name, email, fan, dob) 
select replace("Team","'",''), replace("Role","'",''), replace("Name","'",''), replace("Email","'",''),
cast("FAN" as text), replace("DOB","'",'') from raw_ap_mgr where "Name" is not null;

create table stg_mgr_1_gs (id, name, dob, email, morc);
create table stg_coach_gs (id, name, dob, email, morc);
insert into stg_mgr_1_gs (id, name, dob, email, morc) select "Id Number", "First Name" || ' ' || "Last Name", "Birthdate", "Email", 'M' from raw_managers;
insert into stg_coach_gs (id, name, dob, email, morc) select "Id Number", "First Name" || ' ' || "Last Name", "Birthdate", "Email", 'C' from raw_coaches;

create table stg_mgr_gs (id,name,dob,email,is_mgr, is_coach);
insert into stg_mgr_gs (id,name, dob,email, is_mgr, is_coach)
select coalesce(m.id,c.id),coalesce(m.name,c.name),coalesce(m.dob,c.dob),coalesce(m.email,c.email),
case when m.id is null then "N" else "Y" end as is_mgr,
case when c.id is null then "N" else "Y" end as is_coach
from stg_mgr_1_gs m full join stg_coach_gs c on m.email = c.email;
 

create table stg_mgr_dbs (name,fan,status,last_award_date);
insert into stg_mgr_dbs (name,fan,status,last_award_date) select  name,fan,status,last_award_date from raw_fa_dbs;

create table stg_mgr_wg (name,fan,qual_coach,first_aid_exp,sg_exp, dbs_exp, team_name, youth_qual_ok, adult_qual_ok);
insert into stg_mgr_wg (name,fan,qual_coach,first_aid_exp,sg_exp, dbs_exp, team_name, youth_qual_ok, adult_qual_ok)
  select distinct replace("Name","'",''), replace("FAN", "'",''),
  replace("Highest Coaching Qualification","'",''), replace("First Aid Expiry","'",''), 
  replace("Safeguarding Children Expiry","'",''), replace("DBS Expiry","'",''), 
  replace(replace("Team Name","'",''),'Ashridge Park ',''), replace("Youth team with qualified coach/manager","'",''),replace("Adult team with first aid in football education","'",'') 
  from raw_wgquals;

update stg_mgr_wg set team_name = team_name || " Park" where 
team_name like '%0' or
team_name like '%1' or
team_name like '%2' or
team_name like '%3' or
team_name like '%4' or
team_name like '%5' or
team_name like '%6' or
team_name like '%7' or
team_name like '%8' or
team_name like '%9' ;


create table stg_mgr_fan_photo (id,role,user_id,fan_ok,DOB,photo_ok,fan);
insert into stg_mgr_fan_photo (id,role,user_id,fan_ok,DOB,photo_ok,fan) select 
id,role,user_id,
case when fan = "" then "N" else "Y" end,DOB,
case when photo = "https://system.gotsport.com/users/photos/default.png" then "N" else "Y" end,
fan
from raw_managers_fan_photo;




drop table if exists stg_mgr_all;

create table stg_mgr_all as select 
coalesce (x.name, g.name, w.name, d.name) as name,
coalesce (x.fan, w.fan, d.fan) as fan,
x.email as email, g.email as gotsport_email, 
x.team_name as team, t.team_age as team_age, x.role as role, w.team_name as wg_team,
is_mgr as is_mgr_on_gs, is_coach as is_coach_on_gs, 
d.status as dbs_status,
d.last_award_date as dbs_award_date,
w.qual_coach, w.first_aid_exp, w.sg_exp, w.dbs_exp, 
case when (w.first_aid_exp like 'Expiring%' or w.sg_exp like 'Expiring%' or w.dbs_exp like 'Expiring%') and w.youth_qual_ok = 'Complete' then 'Expiring' else  w.youth_qual_ok end as youth_qual_ok, 
w.adult_qual_ok, case when g.dob = '' then 'N' else 'Y' end as dob_on_gs,
case when x.fan is not null then 'Y' else 'N' end as on_excel,
case when w.fan is not null then 'Y' else 'N' end as on_wg,
case when d.fan is not null then 'Y' else 'N' end as on_dbs,
case when g.email is not null then 'Y' else 'N' end as on_gs,
case when w.fan is null and x.fan is not null then 'Y' else 'N' end as needs_adding_to_wg,
case when g.email is null and x.email is not null then 'Y' else 'N' end as needs_adding_to_gs,
f.fan_ok as fan_on_gotsport, f.photo_ok as photo_on_gotsport, f.fan as gs_fan

from
stg_mgr_xl x full join stg_mgr_dbs d on x.fan = d.fan full join stg_mgr_wg w on (w.fan = x.fan and w.team_name = x.team_name)
full join stg_mgr_gs g on lower(g.email) = lower(x.email) 
left join stg_mgr_fan_photo f on g.id = f.id
left join stg_team_xl t on x.team_name = t.team_name ;

update stg_mgr_all set dbs_exp = null where team_age is null;
update stg_mgr_all set dbs_status = null where dbs_exp > date('now','+3 months');