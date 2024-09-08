#!/usr/bin/env ruby

require_relative 'excel_sqlite.rb'
require 'optparse'
WHITE = "ffffff"
GREEN = "32ff00"
RED = "ff0000"
AMBER = "ffbf00"

xlsdir = "."
dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: excel_to_sqlite.rb [options]"

  opts.on("-x", "--xls-dir XXXX",  "Directory containing xls files") do |u|
    xlsdir = u + "/"
  end

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!



x = SQLiteToExcel.new(xlsdir+"mgr_quals.xlsx","Manager Qualifications",dbfile)
x.add_narrative (["foo"])
x.run_query("select team, name, dbs_status, dbs_exp, sg_exp, first_aid_exp, youth_qual_ok" +
  " from stg_mgr_all where team is not null and role != 'Admin' order by team_age, name;",
{"team" => "Team", "name" => "Name","dbs_status" => "DBS Application", "dbs_exp" => "DBS Expires", "sg_exp" => "Safeguarding Expires",
"first_aid_exp" => "First Aid Expires", "youth_qual_ok" => "Youth Qualifications OK"  })
x.set_widths([30,30,30,20,20,20,15])
x.format_column("dbs_status") do |v|
  if v == "Not started" or (v and v.include? "Required")
    RED
  else 
    if v == "Application in Progress"
      AMBER
    else
      GREEN
     end
  end
end
x.format_column("sg_exp") do |v|
  if v.include? "Expiring"
    AMBER
  else
    if v == "Not Held" or v == "Expired" 
      RED
    else
      GREEN
    end 
  end
end
x.format_column("first_aid_exp") do |v|
  if v.include? "Expiring"
    AMBER
  else
    if v == "Expired" 
      RED
    else
      if v == "Not Held"
        WHITE
      else
        GREEN
      end
    end 
  end
end

x.save

