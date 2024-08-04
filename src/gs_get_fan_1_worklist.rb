#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'date'
require 'fileutils'

require 'sqlite3'
require 'optparse'

$stdout.sync = true
user, pass = Netrc.read["system.gotsport.com"]

dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: gs_get_fan_1_worklist.rb [options]"

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!

class Driver
    def webdriver
      @d
    end
    def initialize(site)
        @options = Selenium::WebDriver::Firefox::Options.new
        @d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: @options

        @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        @d.manage.timeouts.implicit_wait = 30
        @d.manage.delete_all_cookies
        @d.manage.window.resize_to(1920,1080)
        @d.get(site)
    end
    def click(css,msg=nil)
      puts msg if msg
        @wait.until {@d.find_element(:css,css)}
        thing = @d.find_element(:css,css)
        @d.action.move_to(thing,0,-5).perform
        thing.click
        return thing
    end
    def send(css,input)
        @wait.until {@d.find_element(:css,css)}
        thing = @d.find_element(:css,css)
        thing.send_keys input
    end
    def find(css,msg=nil)
        puts msg if msg
        @wait.until {@d.find_element(:css,css)}
        return @d.find_element(:css,css)
    end
    def quit 
        @d.quit
    end
end



puts "Starting.. User is #{user}"

db =   db = SQLite3::Database.new(dbfile)
db.execute("drop table if exists raw_gs_fan_etc;")
db.execute("create table raw_gs_fan_etc (profile_url, first_name, last_name, birthdate, country_birth, country_citizen, fan, fanlocked, namelocked);")


begin

    dl = Driver.new('https://system.gotsport.com')
  

    sleep 15

    puts "Waiting to sign in"

    dl.send('#user_email',user)
    dl.send('#user_password',pass)
    sleep 0.1
    dl.click('.m-b-sm','Signing in..')
    
    sleep 15

# get org ID

  orgid = dl.find('a.active').attribute('href').split("/")[-1]
  puts "Org ID is #{orgid}"
  
  rooturl = 'https://system.gotsport.com/org/'+orgid + '/'


  
# next export players. First all players (don't use any search filters)

  puts "Moving to Players page"
  dl.webdriver.navigate.to(rooturl + 'players')
  sleep 5
  
  pagesize = 100
  org2id = dl.find('.nav > li:nth-child(1) > a:nth-child(1)').attribute('href').split("/")[-2]
  puts "Other Org ID is #{org2id}"
  rc = dl.find('li.fz-sm',"Getting result count..").text
  total = rc[/.*of (.*) in total.*/,1].to_i
  pages = (total / pagesize).floor + 1
  puts "#{rc} so #{pages} pages of #{pagesize}"

  playurl = 'https://system.gotsport.com/org/' + org2id + "/players?utf8=%E2%9C%93&per_page=" + pagesize.to_s + "&page="
  
  db.transaction

  for page in 1..pages do 
  
    dl.webdriver.navigate.to(playurl + page.to_s)
    sleep 2

    table = dl.find('#players-table > tbody:nth-child(2)',"Locating player table for page #{page}")
    rows = table.find_elements(tag_name: 'tr')

    rows.each do |row|
      p = row.find_element(css: 'td:nth-child(2) > div:nth-child(1) > div:nth-child(2) > a:nth-child(1)')
      db.execute("insert into raw_gs_fan_etc (profile_url) values (?);", [p.attribute('href')])
    end

  end

  db.commit

ensure

  dl.quit

end


#    #user-13910211 > td:nth-child(2) > div:nth-child(1) > div:nth-child(2) > a:nth-child(1)
  