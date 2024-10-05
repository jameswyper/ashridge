#!/usr/bin/env ruby

require_relative 'excel_sqlite.rb'
require 'optparse'
WHITE = "ffffff"
GREEN = "32ff00"
RED = "ff0000"
AMBER = "ffbf00"

xlsdir = "."
dbfile = ""
payrep = false
OptionParser.new do |opts|
  opts.banner = "Usage: excel_to_sqlite.rb [options]"

  opts.on("-x", "--xls-dir XXXX",  "Directory containing xls files") do |u|
    xlsdir = u + "/"
  end

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
  opts.on("-p", "--payment-reports", "Include payment tables in reports") do |u|
    payrep = u
  end

end.parse!



x = SQLiteToExcel.new(xlsdir+"progress.xlsx","Registration Progress",dbfile)
x.add_narrative (["Player on Wholegame but not GotSport? Add them to GotSport if they should be there, if not send me details and I'll remove from Wholegame",
  "LPGAF Done means they have completed the registration form.  It does NOT mean they are approved to play",
  "Issues with Photos, ITC etc will show in player's First Name column",
  "If FAN on GotSport is blank AND there is a FAN in the next column please add it to GotSport"])
x.run_query("select team,last_name,first_name,on_gotsport, on_wholegame, parent_attached, case when gs_fan = wg_fan then 'Y' else 'N' end as fan_match, wg_fan, has_lpgaf, has_photo," + 
  "photo_locked, needs_poa, wg_consent, " + 
  "which_email, wg_reg_status " +
  ", case when payment_id is null and (approved is null or approved = 'N') then 'N' else 'Y' end as payment_status" +
  " from player_match" + 
   "a left join payments_match b on a.gs_id = b.gs_id left join staging_spp c on a.gs_id = c.gs_id" + 
  "where agesort is not null and team_gender = 'c' order by agesort, team, last_name, first_name",
  {"team" => "Team", "last_name" => "Last Name", "first_name" => "First Name","on_gotsport" => "On GotSport?",
    "on_wholegame" => "On Wholegame?", "fan_match" => "FAN on GS matches?", "has_lpgaf" => "LPGAF done?", "has_photo" => "Photo on GotSport?",
   "wg_consent" => "FA Consent?", "wg_reg_status" => "FA Registration Status",
     "which_email" => "Whose email needed on Wholegame?", "parent_attached" => "Parent on GotSport?", "wg_fan" => "FAN on Wholegame",
    "needs_poa" => "POA/BP needs to be uploaded?", "photo_locked" => "Photo Approved?", "payment_status" => "Paid?"})
x.set_widths([26,17,17,11,13,14,14,14,11,15,12,11,10,18,18,19,10])
x.namemap.each_value {|v| x.ynrg(v) if v.include? "?"}
x.format_column("fan_match") do |v|
  if v == 'Y'
    GREEN
  else
    if v == 'N'
      RED
    else
      WHITE
    end
  end
end
x.format_column("FA Consent?") {|v| if ['Offline','Online'].include? v then GREEN else RED end}
x.format_column("photo_locked") {|v| if v == 'Y' then GREEN else RED end}
x.format_column("which_email") {|v| if v.include? 'P' then RED else WHITE end}
x.format_column("needs_poa") {|v| if v == 'Y' then RED else GREEN end}
x.format_column("wg_reg_status") do |v| 
  if v == "Registered"
    GREEN
  else 
    if v == "Pending League"
      AMBER
    else
      RED
    end
  end
end
  
x.mask_column("last_name") {|v| v[0] + ("-" * v[1..-2].size) + v[-1]}
x.mask_column("first_name") do |v|
  w = v.split(" ")
  n = w[0][0] + ("-" * w[0][1..-2].size) + w[0][-1]
  w[0] = n
  w.join(" ")
end
x.save

x = SQLiteToExcel.new(xlsdir+"unmatched.xlsx","Unmatched Payments",dbfile)
x.add_narrative (["This page shows players for who we've received payment but can't match the payment to the player",
"We try to match on Team + email + name, Team + email, Team + Name",
"Any unmatched players are likely not on GotSport at all, or using a different email address to ANY we have in GotSport or Wholegame for the player/parent"])
x.run_query("select team_name, player_name, cardholder_name from payments_match where gs_id is null order by team_name, player_name",
  {"team_name" => "Team", "player_name" => "Player Name", "cardholder_name" => "Cardholder"})
x.set_widths([26,17,17])
x.save


x = SQLiteToExcel.new(xlsdir+"addtowg.xlsx","Add to Wholegame",dbfile)
x.add_narrative(["Players on GotSport to be added to Wholegame"])
x.run_query("select first_name, last_name, gs_birthdate, gender, postcode, address, team from player_match where on_wholegame = 'N' and team is not null;",
{"first_name" => "First Name", "last_name" => "Last Name", "gender" => "Gender", "gs_birthdate" => "DOB", "postcode" => "Postcode", "address" => "Address", "team" => "Team"})
x.save

x = SQLiteToExcel.new(xlsdir+"consentwg.xlsx","Consent on Wholegame",dbfile)
x.add_narrative(["Players with LPGAF ready for Consent"])
x.run_query("select last_name, first_name from player_match where on_wholegame = 'Y' and has_lpgaf = 'Y' and wg_consent = '-';",
  {"first_name" => "First Name", "last_name" => "Last Name"})
x.save

x = SQLiteToExcel.new(xlsdir+"playeremail.xlsx","Player Email Required",dbfile)
x.add_narrative(["Players needing their own email address on Wholegame"])
x.run_query("select first_name, last_name, wg_birthdate, parent_one_email, parent_two_email from player_match where " + 
 "on_wholegame = 'Y' and which_email = 'Player' and agesort is not null and team_gender = 'c' ",{"first_name" => "First Name", "last_name" => "Last Name"})
x.save