#!/usr/bin/env ruby


require 'optparse'
require_relative 'excel_sqlite.rb'

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




ExcelToSQLite.new(xlsdir + "wg_quals.xlsx",dbfile,"raw_wgquals","Team Qualifications Report",10)

ExcelToSQLite.new(xlsdir + "master.xlsx",dbfile,"raw_ap_mgr","flat",1)
ExcelToSQLite.new(xlsdir + "master.xlsx",dbfile,"raw_ap_team","teams",1)