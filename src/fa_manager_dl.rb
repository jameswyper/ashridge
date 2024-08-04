#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
$stdout.sync = true
user, pass = Netrc.read["wholegame.thefa.com"]
puts "Starting.."

begin

options = Selenium::WebDriver::Firefox::Options.new
d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: options

wait = Selenium::WebDriver::Wait.new(:timeout => 30)
d.manage.timeouts.implicit_wait = 30
d.manage.delete_all_cookies
d.get('https://wholegame.thefa.com')

puts "Loaded first page, waiting for cookie pop-up"

wait.until { d.find_element(:id ,"onetrust-accept-btn-handler") }
cookie = d.find_element(:id,"onetrust-accept-btn-handler")
sleep 1
if (cookie) then cookie.click end
sleep 1
puts "Waiting to sign in"
wait.until {d.find_element(:id,"signInName")}
d.find_element(:id,"signInName").send_keys user
d.find_element(:id,"password").send_keys pass
wait.until { d.find_element(:id , "next") }
button = d.find_element(:class,"buttons")
signin = d.find_element(:id,"next")
d.action.move_to(button).perform
signin.click
puts "Signing in.."
sleep 5
puts "Waiting for another cookie pop-up.."
wait.until { d.find_element(:id ,"BtnAcceptCookies") }
c = d.find_element(:id ,"BtnAcceptCookies")
wait.until {c.displayed?}
#puts "button text is "+ d.find_element(:id , "BtnAcceptCookies").text
d.find_element(:id,"BtnAcceptCookies").click   

puts "Going to Club Secretary tab"

wait.until { d.find_element(:partial_link_text,"Club Secretary") }
club = d.find_element(:partial_link_text,"Club Secretary")   
club.click

puts "Going to Team Officials tab"

wait.until { d.find_element(:link_text,"Team Officials") }
team = d.find_element(:link_text,"Team Officials" )
team.click

sleep 10

puts "Accepting cookies again"
wait.until { d.find_element(:id ,"onetrust-accept-btn-handler") }
cookie = d.find_element(:id,"onetrust-accept-btn-handler")
sleep 1
if (cookie) then cookie.click end
sleep 1

puts "Clicking on Safeguarding Tab"

safexpath  = "/html/body/app-root/div[1]/app-portal/div/div[2]/app-core/div/mat-sidenav-container/mat-sidenav-content/official-listing/div/div[1]/div[3]/app-secondary-navigation/div/div/div[3]"

wait.until { d.find_element(:xpath,safexpath) }
safe = d.find_element(:xpath,safexpath)
raise "Unexpected text on Safeguarding tab: #{safe.text}" unless safe.text == "Safeguarding & Qualifications"
safe.click

puts "Clicking on Export"
exportxpath = "/html/body/app-root/div[1]/app-portal/div/div[2]/app-core/div/mat-sidenav-container/mat-sidenav-content/official-listing/div/div[2]/safeguarding-listing/div/div[1]/div[1]/div[1]/div/div[2]/button"


wait.until {d.find_element(:xpath,exportxpath)}
export = d.find_element(:xpath,exportxpath)
raise "Unexpected text on Export button: #{export.text}" unless export.text == "Export Team Officials"
export.click

puts "Clicking on Download"
dlxpath = "/html/body/div[3]/div[2]/div/mat-dialog-container/export-team-officials-popup/div/div[2]/div[2]/button[2]"

wait.until {d.find_element(:xpath,dlxpath)}
dl = d.find_element(:xpath,dlxpath)
raise "Unexpected text on Download button: #{dl.text}" unless dl.text == "DOWNLOAD"
dl.click
sleep 15

ensure

d.quit

end


