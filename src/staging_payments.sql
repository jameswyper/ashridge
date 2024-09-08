drop table if exists stg_payments;
drop table if exists payments_match;

create table stg_payments (id,timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name);

insert into stg_payments (id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name)
select id, "Created date (UTC)", Amount, Status, "Decline Reason", "Payment Source Type", "Card Name",
  "Customer Email","Checkout Custom Field 1 Value","Checkout Line Item Summary" from raw_payments;

update stg_payments set team_name = substr(team_name, 1, instr(team_name, '(')-2);
update stg_payments set team_name = replace(team_name,'Under ', 'U');
update stg_payments set team_name = replace(team_name,"'s",'');
update stg_payments set team_name = replace(team_name,' Park','');
update stg_payments set team_name = 'Ashridge Park ' || team_name;

drop table if exists payments_match_name;
drop table if exists payments_match_no_name;
drop table if exists payments_match_name_only;
drop table if exists payments_match;

create table payments_match_name (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id);

insert into payments_match_name (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id) 
  select a.id, a.timestamp, a.amount, a.status, a.decline_reason, a.source, a.cardholder_name,
  a.cardholder_email, a.player_name, a.team_name, b.gs_id from stg_payments a left outer join player_match b
  on a.team_name = b.gs_team 
  and (lower(a.cardholder_email) = lower(b.parent_one_email) or lower(a.cardholder_email) = lower(b.parent_two_email) 
       or lower(a.cardholder_email) = lower(b.contact_email) or lower(a.cardholder_email) = lower(b.wg_parent_email) )
  and ( lower(substr(a.player_name,1,instr(a.player_name,' ')-1)) 
    =  case when instr(b.first_name,' ') = 0 then lower(first_name) else lower(substr(b.first_name,1,instr(b.first_name,' ')-1)) end )
where status = 'Paid';


create table payments_match_no_name (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id);

insert into payments_match_no_name (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id) 
  select a.id, a.timestamp, a.amount, a.status, a.decline_reason, a.source, a.cardholder_name,
  a.cardholder_email, a.player_name, a.team_name, b.gs_id from stg_payments a left outer join player_match b
  on a.team_name = b.gs_team 
  and (lower(a.cardholder_email) = lower(b.parent_one_email) or lower(a.cardholder_email) = lower(b.parent_two_email) 
       or lower(a.cardholder_email) = lower(b.contact_email) or lower(a.cardholder_email) = lower(b.wg_parent_email) )
where status = 'Paid';

delete from payments_match_no_name where payment_id in (select payment_id from payments_match_name where gs_id is not null);

create table payments_match_name_only (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id);

insert into payments_match_name_only (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id) 
  select a.id, a.timestamp, a.amount, a.status, a.decline_reason, a.source, a.cardholder_name,
  a.cardholder_email, a.player_name, a.team_name, b.gs_id from stg_payments a left outer join player_match b
  on a.team_name = b.gs_team 
  and lower(trim(a.player_name)) = lower(b.first_name) || ' ' || lower(b.last_name) 
where status = 'Paid';

create table payments_match (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id);

insert into payments_match  (payment_id, timestamp, amount, status, decline_reason, source, cardholder_name,
  cardholder_email, player_name, team_name, gs_id)
  select distinct a.payment_id, a.timestamp, a.amount, a.status, a.decline_reason, a.source, a.cardholder_name,
  a.cardholder_email, a.player_name, a.team_name, coalesce (a.gs_id, b.gs_id, c.gs_id)
  from payments_match_name a left outer join payments_match_no_name b on a.payment_id = b.payment_id
  left outer join payments_match_name_only c on a.payment_id = c.payment_id;


