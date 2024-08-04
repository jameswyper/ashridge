#!/usr/bin/env ruby

require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'sqlite3'
require 'optparse'


xlsdir = "."
dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: excel_to_sqlite.rb [options]"

  opts.on("-x", "--xls-dir XXXX",  "Directory containing downloaded xls files") do |u|
    xlsdir = u + "/"
  end

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!


class ExcelToSQLite
  
  def initialize(xls,db,table,sheet,hdr = 1)
    db = SQLite3::Database.new(db)
    w = RubyXL::Parser.parse(xls)
    s = w[sheet]
    hrow = s[hdr-1]
    c = 0
    tabcols = Array.new
    while (hrow[c]) do
      tabcols << hrow[c].value
      c = c + 1
    end
    cols = c    
    collist = "(" + tabcols.collect{|x| '"' + x + '"'}.join(",") + ")"
    qlist = "(" + tabcols.collect {|x| "?"}.join(",") + ")"
    dropstmt = "drop table if exists " + table + ";"
    crstmt =  "create table " + table + " " + collist + ";"
    db.execute(dropstmt)
    db.execute(crstmt)
    db.transaction
    rr = hdr
    while (s[rr]) do
      row = Array.new
      for c in 0..(cols-1) do
        row << if (s[rr][c] && s[rr][c].value) 
                  v = s[rr][c].value
                  if v.kind_of?(Integer)
                    v
                  else
                    if v.kind_of?(DateTime)
                      "'" + v.strftime('%Y-%m-%d') + "'"
                    else  
                      "'" + v + "'"
                    end
                  end
              else 
                  nil 
              end
          end
      stmt = "insert into " + table + " " + collist + " values " + qlist + ";"

      db.execute(stmt, row)
      
      rr = rr + 1
    end
    db.commit
  end
end

ExcelToSQLite.new(xlsdir + "wg_quals.xlsx",dbfile,"raw_wgquals","Team Qualifications Report",10)
ExcelToSQLite.new(xlsdir + "wg_reg.xlsx",dbfile,"raw_wgreg","Club - Player Report",7)