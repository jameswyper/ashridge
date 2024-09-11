
drop table if exists staging_spp;
create table staging_spp (gs_id, approved);

insert into staging_spp (gs_id, approved) select "GotSport ID", "Approved?" from raw_spp;