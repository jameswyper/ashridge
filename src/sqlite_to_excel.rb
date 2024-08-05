#!/usr/bin/env ruby

require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'sqlite3'
require 'optparse'
WHITE = "ffffff"
GREEN = "32ff00"
RED = "ff0000"

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

class SQLiteToExcel
  attr_reader :namemap
  def initialize(xls,sheet,db)
    
    #bug means we can't add to existing workbooks
    #if File.exist? xls
    #   @xl = RubyXL::Workbook.parse(xls)
    #   @s = @xl.add_worksheet(sheet)
    #else
    
      @xl = RubyXL::Workbook.new
      @s = @xl['Sheet1']
      @s.sheet_name = sheet
    #end
    @db = SQLite3::Database.new(db)
    @xlsfile = xls


    @row = 0
    @colnames = Array.new
    @namemap = Hash.new
  end
  
  def add_narrative(n)
    @s.add_cell(@row,0,"Produced on #{Time.now.strftime("%d/%m/%Y %H:%M")}")
    @row = @row + 1
    n.each do |l|
      @s.add_cell(@row,0,l)
      @row = @row + 1
    end
  end
  

  def run_query(q,namemap)
    @namemap = namemap
    res = @db.query(q)
    res.columns.each do |c|
      @colnames << (namemap[c] || c)
    end
    @row = @row + 1

    col = 0
    @colnames.each do |c| 
      @s.add_cell(@row,col,c)
      col = col + 1
    end
    @row = @row + 1
    @firstrow = @row
    res.each do |row|
      col = 0
      row.each do |v|
        @s.add_cell(@row,col,v)
        col = col + 1
      end
      @row = @row + 1
    end
    @lastrow = @row - 1
  end
  
  def find_column(col)
    return @colnames.find_index(@namemap[col] || col)
  end

  def format_column(col)
    c = find_column(col)
    for r in @firstrow..@lastrow do
      @s[r][c].change_fill (yield(@s[r][c].value) || WHITE)
    end

  end
  
  def ynrg(col)
    format_column(col) {|s| if s == "Y" then GREEN else RED end}
  end

  def mask_column(col)
    c = find_column(col)
    for r in @firstrow..@lastrow do
      @s[r][c].change_contents(yield(@s[r][c].value) )
    end

  end
  def set_widths(w)
    w.each_index {|i| @s.change_column_width(i, w[i])}
  end

  def save
    worksheetview = RubyXL::WorksheetView.new
    worksheetview.pane = RubyXL::Pane.new(:top_left_cell => RubyXL::Reference.new(0,@firstrow), :x_split => 0, :y_split => @firstrow, :state => 'frozen')
    worksheetviews = RubyXL::WorksheetViews.new
    worksheetviews << worksheetview
    @s.sheet_views = worksheetviews
    @xl.write(@xlsfile)
  end

end

x = SQLiteToExcel.new(xlsdir+"progress.xlsx","Registration Progress",dbfile)
x.add_narrative (["Player on Wholegame but not GotSport? Add them to GotSport if they should be there, if not send me details and I'll remove from Wholegame",
  "LPGAF Done means they have completed the registration form.  It does NOT mean they are approved to play",
  "Issues with Photos, ITC etc will show in player's First Name column",
  "If FAN on GotSport is blank AND there is a FAN in the next column please add it to GotSport"])
x.run_query("select team,last_name,first_name,on_gotsport, on_wholegame, parent_attached, has_fan, wg_fan, has_lpgaf, has_photo," + 
  "photo_locked, needs_poa, wg_consent, " + 
  "which_email, wg_reg_status" +
  " from player_match where agesort is not null and team_gender = 'c' order by agesort, team, last_name, first_name",
  {"team" => "Team", "last_name" => "Last Name", "first_name" => "First Name","on_gotsport" => "On GotSport?",
    "on_wholegame" => "On Wholegame?", "has_fan" => "FAN on GotSport?", "has_lpgaf" => "LPGAF done?", "has_photo" => "Photo on GotSport?",
   "wg_consent" => "FA Consent?", "wg_reg_status" => "FA Registration Status",
     "which_email" => "Whose email needed?", "parent_attached" => "Parent on GotSport?", "wg_fan" => "FAN on Wholegame",
    "needs_poa" => "POA needs to be uploaded?", "photo_locked" => "Photo Approved?"})
x.set_widths([26,17,17,11,13,14,14,14,11,15,12,11,10,18,18,19])
x.namemap.each_value {|v| x.ynrg(v) if v.include? "?"}
x.format_column("FA Consent?") {|v| if ['Offline','Online'].include? v then GREEN else RED end}
x.format_column("photo_locked") {|v| if v == 'Y' then GREEN else RED end}
x.format_column("which_email") {|v| if v.include? 'P' then RED else WHITE end}
x.format_column("needs_poa") {|v| if v == 'Y' then RED else GREEN end}

x.mask_column("last_name") {|v| v[0] + ("-" * v[1..-2].size) + v[-1]}
x.mask_column("first_name") do |v|
  w = v.split(" ")
  n = w[0][0] + ("-" * w[0][1..-2].size) + w[0][-1]
  w[0] = n
  w.join(" ")
end
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
