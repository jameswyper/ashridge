#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
require 'date'
require 'fileutils'
require 'sqlite3'
require 'optparse'

$stdout.sync = true
THREADS = 8
user, pass = Netrc.read["system.gotsport.com"]

dbfile = ""
OptionParser.new do |opts|
  opts.banner = "Usage: gs_get_fan_1_worklist.rb [options]"

  opts.on("-d", "--db-file DDDD",  "SQLite database file") do |u|
    dbfile = u
  end
  
end.parse!

pids = Array.new
for t in 0..(THREADS-1) do
   pids << spawn('geckodriver','--binary=/usr/bin/firefox','--port=' + (t + 5000).to_s)
end


db = SQLite3::Database.new(dbfile)

class Driver
    def webdriver
      @d
    end
    def initialize(site,port=4444)
        @options = Selenium::WebDriver::Firefox::Options.new
        @d = Selenium::WebDriver.for :remote, url: 'http://localhost:' + port.to_s, options: @options

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

Thread.abort_on_exception = true

puts "Starting.. User is #{user}"
begin
  
  semaphore = Mutex.new
  threads = Array.new
  dl = Array.new
  tt = Array.new
  for h in 0..(THREADS-1) do tt[h] = h end

  for h in 0..(THREADS-1) do
    
    threads << Thread.new do    
      
      semaphore.synchronize {t = tt.pop}

      puts "Thread #{t} starting"
      
      dl[t] = Driver.new('https://system.gotsport.com',t + 5000)
  
      sleep 10

      puts "Thread #{t} waiting to sign in"

      dl[t].send('#user_email',user)
      dl[t].send('#user_password',pass)
      sleep 0.1
      dl[t].click('.m-b-sm','Signing in..')
    
      sleep 10
      puts "Thread #{t} signed in"
    end
  
  end

  threads.each(&:join)

  rows = db.query("select profile_url from raw_gs_fan_etc where last_name is null;")
  
  #spread the rows across our threads

  purl = Array.new
  t = 0
  rows.each do |row|
    if purl[t]
      purl[t] << row[0]
    else
      purl[t] = [row[0]]
    end
    t = t + 1
    if t == THREADS
      t = 0
    end
  end
  

  threads = Array.new

  tt = Array.new
  for h in 0..(THREADS-1) do tt[h] = h end

  for h in 0..(THREADS-1) do
    
    threads << Thread.new do    
      
      semaphore.synchronize {t = tt.pop}
   

      purl.each do |thisurl|

        dl[t].webdriver.navigate.to(thisurl)
        sleep 2
        firstname = dl[t].find('#user_first_name').attribute('value')
        readonly = dl[t].find('#user_first_name').attribute('readonly')
        lastname = dl[t].find('#user_last_name').attribute('value')

      
        begin
          f = dl[t].webdriver.find_element(css: '#user_fan_number')
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

        itc_birth = Selenium::WebDriver::Support::Select.new(dl[t].find('#user_itc_country_of_birth')).selected_options[0].text
        itc_citz = Selenium::WebDriver::Support::Select.new(dl[t].find('#user_itc_country_of_citizenship_')).selected_options[0].text
        birthyear = Selenium::WebDriver::Support::Select.new(dl[t].find('#user_birthdate_1i')).selected_options[0].text
        birthmonth = Selenium::WebDriver::Support::Select.new(dl[t].find('#user_birthdate_2i')).selected_options[0].attribute("value")
        birthday = Selenium::WebDriver::Support::Select.new(dl[t].find('#user_birthdate_3i')).selected_options[0].text

        
        birthdate = birthyear + "-" + ("0" + birthmonth).right(2) + "-" + birthday

        puts "Thread #{t} #{firstname} #{lastname} - Locked? #{readonly} - " + 
            "#{birthyear}-#{birthmonth}-#{birthday} #{birthdate} #{itc_birth} #{itc_citz} FAN:#{fan} #{fanlocked}"


        semaphore.synchronize do
           db.execute("update gs_raw_fan_etc set first_name = ?, last_name = ?, birthdate = ?, country_birth = ?," +
            "country_citizen = ?, fan = ?, fanlocked = ?, namelocked = ?where profileurl = ?",
             firstname,lastname,birthdate,itc_birth,itc_citz,fan,fanlocked,readonly,thisurl)
        end

      end
    end

 
  
  end
  threads.each(&:join)
ensure
  
  dl.each {|d| d.quit}
  puts "Terminating Geckodriver processes"
  pids.each {|p| Process.kill('TERM',p)}
  puts "All terminated"
  Process.waitall

end



  