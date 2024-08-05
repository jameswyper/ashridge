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
ply = nil
OptionParser.new do |opts|
  opts.banner = "Usage: gs_get_fan_1_worklist.rb [options]"

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
  opts.on("-p=s", "--ply=s", "Which parallel thread") do |p|
    ply = p
  end

end.parse!



db = SQLite3::Database.new(dbfile)

class Driver
    def webdriver
      @d
    end
    def initialize(site,port=4444)
        @options = Selenium::WebDriver::Firefox::Options.new
        @d = Selenium::WebDriver.for :remote, url: 'http://localhost:' + port.to_s, options: @options

        @wait = Selenium::WebDriver::Wait.new(:timeout => 2)
        @d.manage.timeouts.implicit_wait = 2
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
begin
  

      if ply
        table = "raw_gs_fan_etc" + ply
        puts "Parallel processing for ply #{ply}"
      else
        table = "raw_gs_fan_etc"
        puts "Not processing in parallel"
      end
      
      dl = Driver.new('https://system.gotsport.com')
  
      sleep 10

      puts  "Waiting to sign in"

      dl.send('#user_email',user)
      dl.send('#user_password',pass)
      sleep 0.1
      dl.click('.m-b-sm','Signing in..')
    
      sleep 10
      puts "Signed in"

  
  



  rows = db.query("select profile_url from #{table} where last_name is null;")
  

  rows.each do |row| 

      thisurl = row [0]

      dl.webdriver.navigate.to(thisurl)
      sleep 2
      firstname = dl.find('#user_first_name').attribute('value')
      readonly = dl.find('#user_first_name').attribute('readonly')
      lastname = dl.find('#user_last_name').attribute('value')

      
      begin
        f = dl.webdriver.find_element(css: '#user_fan_number')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        f = nil
      end

      if f
        fan = f.attribute('value')
        fanlocked = f.attribute('readonly')
      else
        fan = nil
        fanlocked = nil
      end

      begin
        p = dl.webdriver.find_element(css: '#js-user-photo-field')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        p = nil
      end

      if p
        photolocked = "N"
      else
        photolocked = "Y"
      end

      begin
        d = dl.webdriver.find_element(css: 'a.text-danger:nth-child(5)')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        d = nil
      end

      if d
        photopresent = "Y"
      else
        photopresent = "N"
      end

      itc_birth = Selenium::WebDriver::Support::Select.new(dl.find('#user_itc_country_of_birth')).selected_options[0].text
      itc_citz = Selenium::WebDriver::Support::Select.new(dl.find('#user_itc_country_of_citizenship_')).selected_options[0].text
      birthyear = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_1i')).selected_options[0].text
      birthmonth = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_2i')).selected_options[0].attribute("value")
      birthday = Selenium::WebDriver::Support::Select.new(dl.find('#user_birthdate_3i')).selected_options[0].text

        
      birthdate = birthyear + "-" + ("0" + birthmonth)[-2..-1] + "-" + ("0" + birthday)[-2..-1]

      puts "#{firstname} #{lastname} - Locked? #{readonly} - " + 
            "#{birthyear}-#{birthmonth}-#{birthday} #{birthdate} #{itc_birth} #{itc_citz} FAN:#{fan} locked:#{fanlocked} photolocked:#{photolocked} photopresent:#{photopresent}"


      db.execute("update #{table} set first_name = ?, last_name = ?, birthdate = ?, country_birth = ?," +
            "country_citizen = ?, fan = ?, fanlocked = ?, namelocked = ?, photolocked = ? , photopresent = ? where profile_url = ?",
             firstname,lastname,birthdate,itc_birth,itc_citz,fan,fanlocked,readonly,photolocked,photopresent,thisurl)
  end 

ensure
  
  dl.quit
  
end



  