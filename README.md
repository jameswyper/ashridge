THE LEGAL STUFF

This software is copyright James Wyper and is licensed under the GNU GPL v3: https://www.gnu.org/licenses/gpl-3.0.en.html
In short that means you are free to use it and to alter it.  You may only distribute modified versions under the terms of the licence above.

This code is provided "as-is" without any warranty or support whatsoever.  While I'll try to help with any problems or questions you have, I can't make any guarantees.  You should also bear in mind that the nature of this code means that if either GotSport or the FA make any changes to their websites it's likely to break.

INTRODUCTION

These are a set of scripts I've developed for automatically downloading, processing and matching data from the GotSport and England FA Wholegame system.  They are written primarily for teams playing in EBFA (East Berks Football Alliance) but the basic webscraping should work for any League and the changes needed to adapt the SQL and reporting should be easy.

THE DESIGN (such as it is)

1.  Download several exports from GotSport: All teams, all Coaches, all Managers, all Players and all Saved Searches of players (the EBFA have set up several filters for e.g. players without a photo uploaded) - gs_dl.rb
2.  Download manager and player details from Wholegame - fa_manager_dl.rb, fa_player_dl.rb and fa_fetch_dl.rb.  fa_fetch_dl needs to be run after fa_manager_dl and again after fa_player_dl - so the sequence is manager/fetch/player/fetch.
3.  Rename the downloaded FA files to wg_quals.xlsx (managers) and wg_reg.xlsx (players)
4.  Import those two spreadsheets into the database - excel_to_sqlite.rb
5.  Scrape each player on GotSport to get their FAN and a few other details.  This is run in two stages: gs_get_fan_1_worklist.rb will create a database table with the URL of each player page.  gs_get_fan_2_process.rb will visit each URL, scrape the details and update the table but _only_ for players who haven't yet been scraped. It should therefore be possible to restart/rerun this program in the event that it aborts (the need to load each player page makes it quite slow - about 4 players per minute, so having to rerun from scratch would be annoying).
6.  Load the exported CSV files from step 1 into the database - load_raw.sql
7.  Transform the raw data as loaded into something more presentable and join the data from the various systems together - staging.sql
8.  Create reports - TBC


GETTING STARTED

You'll need credentials for the system you want to extract data from.  For Wholegame that means something like the "Club Secretary" role and for GotSport a "Club Admin" one.

You need to be familiar with Linux and ideally Docker.  If you understand the Ruby programming language you've got a fighting chance of doing some of your own debugging.  The browser automation uses Selenium and the data processing is based around SQL so knowledge of either of those will help.

With Docker (recommended)

Build and tag the image in the docker directory, and launch it with at least the following volumes (locations below are mount points inside the container)
-   /home/james/code - put the contents of the src directory here
-   /home/james/data - processed results will go here
-   /home/james/.netrc - a .netrc format file with credentials for the two systems

(to save you searching - the .netrc format is one line per website with the syntax "machine <website> user <username> password <password>" for each website i.e. GotSport and Wholegame, without the double quotes)

Run the image. To run one of the programs use something like 'docker exec -u james <container name> bash -c "ruby /path/to/program" '

Without Docker

Check the Dockerfile in the docker directory for the latest, but in brief you'll need to have the following software installed:
    Firefox (can be run in headless mode if your server doesn't support a GUI - set MOZ_HEADLESS=1 before launching geckodriver
    Geckodriver (I've tested with the offical Mozilla release 0.33 built for 64-bit ARM systems)
    The following Ruby packages (best added with Gem): rubyXL, netrc, sqlite3 and selenium-webdriver
    If you're using Visual Studio Code to hack and debug this you'll need debug and ruby-debug-ide as well

To run, firstly start geckodriver with geckodriver --binary=/usr/bin/firefox (and optionally --log=debug.  Obvs if your firefox is installed to a different location use that).  The run one of the programs with ruby /path/to/program.

PROBLEMS

Failures with the webscraper programs are sometimes caused by transient issues with the sites themselves or general Internet reliability.  It's worth retrying a failed program to see if it works second or third time.  If it consistently fails in the same place it's likely the website itself has changed and the programs will need to be fixed.