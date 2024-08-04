#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'netrc'
$stdout.sync = true
user, pass = Netrc.read["wholegame.thefa.com"]


puts "Starting.."
puts "User is #{user}"
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

puts "Going to Player Registration"

wait.until { d.find_element(:link_text,"Player Registration") }
team = d.find_element(:link_text,"Player Registration" )
team.click

sleep 15

puts "Dealing with a another cookie pop-up"

wait.until { d.find_element(:id ,"onetrust-accept-btn-handler") }
cookie = d.find_element(:id,"onetrust-accept-btn-handler")
sleep 1
if (cookie) then cookie.click end
sleep 1

puts "Finding and Clicking on Export"
wait.until {d.find_element(:css,"button.mat-menu-trigger:nth-child(2)")}
export = d.find_element(:css,"button.mat-menu-trigger:nth-child(2)")
raise "Unexpected text on Export button: #{export.text}" unless export.text == "Export"
export.click

puts "Finding Player button"
player = d.find_element(:css,".menu-content > button:nth-child(3)")
raise "Unexpected text on Export button: #{player.text}" unless player.text == "Player Information"
player.click

puts "Finding confirm button"

confirm = d.find_element(:css,"button.dialog-btn.emphasised-btn.fa-blue")
raise "Unexpected text on Confirm button: #{confirm.text}" unless confirm.text == "CONFIRM"
confirm.click

puts "waiting for download"

sleep 30


ensure

d.quit

end