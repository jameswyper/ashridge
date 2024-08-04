
require 'selenium-webdriver'

$stdout.sync = true

puts "Starting.."

begin

options = Selenium::WebDriver::Firefox::Options.new
d = Selenium::WebDriver.for :remote, url: 'http://localhost:4444', options: options
d.manage.window.resize_to(1920,7000)

wait = Selenium::WebDriver::Wait.new(:timeout => 30)
d.manage.timeouts.implicit_wait = 10
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
d.find_element(:id,"signInName").send_keys "wyperjamesr@gmail.com"
d.find_element(:id,"password").send_keys "------"
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

puts "Clicking on Safeguarding Tab"

safexpath  = "/html/body/app-root/div[1]/app-portal/div/div[2]/app-core/div/mat-sidenav-container/mat-sidenav-content/official-listing/div/div[1]/div[3]/app-secondary-navigation/div/div/div[3]"

wait.until { d.find_element(:xpath,safexpath) }
safe = d.find_element(:xpath,safexpath)
raise "Unexpected text on Safeguarding tab: #{safe.text}" unless safe.text == "Safeguarding & Qualifications"
safe.click

wait.until { d.find_element(:class,"count-ctr")}
off_ct = d.find_element(:class,"count-ctr")

puts "Page says there are #{off_ct.text}"
oc = off_ct.text.split(" ")[0].to_i
os = 0
los = 0
sc = 2
d.execute_script("window.scrollTo(0,6800)")
offrows = d.find_elements(:css,".table-row")
os = offrows.size
puts "os is #{os}"
=begin
while (os != los) do
    d.action.scroll_to(offrows[sc]).perform
    #r = d.execute_script("window.scrollTo(#{w})")
    #puts "result is #{r} when w is #{w}"
    #w = w + 1000
    
    offrows = d.find_elements(:css,".table-row")
    los = os
    os = offrows.size
    sc = sc + 3
    puts "os is #{os}"
end
=end

ensure

d.quit

end

