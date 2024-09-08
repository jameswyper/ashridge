drop table if exists stg_mgr_wg;
drop table if exists stg_mgr_dbs;
drop table if exists stg_mgr_gs;
drop table if exists stg_mgr_xl;
drop table if exists stg_team_xl;

create table stg_team_xl (team_name, team_age, training_time, training_day, training_venue);
insert into stg_team_xl (team_name, team_age, training_time, training_day, training_venue) 
  select replace("Team Name","'",''),cast("Team Age" as int), replace("Training Time","'",''),
  replace("Training Day","'",''),replace("Training Venue","'",'') from raw_ap_team where "Team Name" is not null;

create table stg_mgr_xl (team_name, role, name, email, fan, dob);
insert into stg_mgr_xl (team_name, role, name, email, fan, dob) 
select replace("Team","'",''), replace("Role","'",''), replace("Name","'",''), replace("Email","'",''),
cast("FAN" as text), replace("DOB","'",'') from raw_ap_mgr where "Name" is not null;

create table stg_mgr_gs (name, dob, email, morc);
insert into stg_mgr_gs (name, dob, email, morc) select "First Name" || ' ' || "Last Name", "Birthdate", "Email", 'M' from raw_managers;
insert into stg_mgr_gs (name, dob, email, morc) select "First Name" || ' ' || "Last Name", "Birthdate", "Email", 'C' from raw_coaches;

create table stg_mgr_dbs (name,fan,status,last_award_date);
insert into stg_mgr_dbs (name,fan,status,last_award_date) select  name,fan,status,last_award_date from raw_fa_dbs;

create table stg_mgr_wg (name,fan,qual_coach,first_aid_exp,sg_exp, dbs_exp, team_name, youth_qual_ok, adult_qual_ok);
insert into stg_mgr_wg (name,fan,qual_coach,first_aid_exp,sg_exp, dbs_exp, team_name, youth_qual_ok, adult_qual_ok)
  select distinct replace("Name","'",''), replace("FAN", "'",''),
  replace("Highest Coaching Qualification","'",''), replace("First Aid Expiry","'",''), 
  replace("Safeguarding Children Expiry","'",''), replace("DBS Expiry","'",''), 
  replace("Team Name","'",''), replace("Youth team with qualified coach/manager","'",''),replace("Adult team with first aid in football education","'",'') 
  from raw_wgquals;

drop table if exists stg_mgr_all;

create table stg_mgr_all as select 
coalesce (x.name, g.name, w.name, d.name) as name,
coalesce (x.fan, w.fan, d.fan) as fan,
x.email as email, g.email as gotsport_email, 
x.team_name as team, t.team_age as team_age, x.role as role, w.team_name as wg_team,
case when g.morc = 'M' then 'Manager' when g.morc = 'C' then 'Coach' else null end as gs_morc, 
d.status as dbs_status,
d.last_award_date as dbs_award_date,
w.qual_coach, w.first_aid_exp, w.sg_exp, w.dbs_exp, w.youth_qual_ok, w.adult_qual_ok, g.dob as gs_dob,
case when x.fan is not null then 'Y' else 'N' end as on_excel,
case when w.fan is not null then 'Y' else 'N' end as on_wg,
case when d.fan is not null then 'Y' else 'N' end as on_dbs,
case when g.email is not null then 'Y' else 'N' end as on_gs

from
stg_mgr_xl x full join stg_mgr_dbs d on x.fan = d.fan full join stg_mgr_wg w on w.fan = x.fan 
full join stg_mgr_gs g on lower(g.email) = lower(x.email) left join stg_team_xl t on x.team_name = t.team_name ;

update stg_mgr_all set dbs_exp = null where team_age is null;
update stg_mgr_all set dbs_status = null where dbs_exp > date('now','+3 months');