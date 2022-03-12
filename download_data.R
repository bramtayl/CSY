library(countrycode)
library(dplyr)
library(purrr)
library(readr)
library(RSelenium)
library(rvest)

# before you run RSelenium, you need to pull and open the docker image:
# sudo docker pull selenium/standalone-firefox
# sudo docker run --detach --publish 4445:4444 selenium/standalone-firefox
# when you are done, close all docker images:
# sudo docker stop (sudo docker ps --quiet)
browser = remoteDriver(port = 4445)
browser$open()

# extract the table from the website
save_table = function(browser, country, page) {
  browser$getPageSource() %>%
    .[[1]] %>%
    read_html %>%
    html_node(css = "#_ctl0_MainContent_TabContainer1_TabPanel1_dgEmployees") %>%
    html_table(header = TRUE) %>%
    write_csv(paste0("data/countries/", country, " ", page, ".csv"))
}

get_first_page = function(browser, country, load_time = 15) {
  message(country)
  browser $
    navigate("http://healtheconomics.tuftsmedicalcenter.org/cear2n/search/search.aspx")
  # click "Ratios"
  browser $
    findElement(using = "css", "#_ctl0_MainContent_TabContainer1_TabPanel1_rule0_1") $
    clickElement()
  # fill in "Full Seach Contents:"
  browser $ 
    findElement(using = "css", "#_ctl0_MainContent_TabContainer1_TabPanel1_query0") $ 
    sendKeysToElement(list(country))
  # click "Search"
  browser $ 
    findElement(using = "css", "#_ctl0_MainContent_TabContainer1_TabPanel1_Button0") $
    clickElement()
  message("Loading page 0")
  # wait for page to load
  Sys.sleep(load_time)
}

get_country = function(browser, country, load_time = 15) {
  get_first_page(browser, country, load_time = load_time)
  save_table(browser, country, 0)

  # some countries return more than 1 page of results  
  extra_pages = browser$findElements(using = "css", "tr:nth-child(22) a")
  if (length(extra_pages) > 0) {
    for (page in 1:length(extra_pages)) {
      # the ith page listed will always refer to the next page plus 1
      # X 2 3, i = 1 is page 2
      # 1 X 3, i = 2 is page 3
      extra_pages[[page]]$clickElement()
      message(paste("Loading page", page))
      # wait for the page to load
      Sys.sleep(load_time)
      # now we're on a new page, relist pages
      extra_pages = browser$findElements(using = "css", "tr:nth-child(22) a")
      save_table(browser, country, page)
    }
  }
}

# dummy run to set options
get_first_page(browser, "Sudan")
# click "Pick Columns to Display(Sort by)"

browser $
  findElement(using = "css", "a:nth-child(4)") $
  clickElement()
# click all columns
walk(
  browser$findElements(using = "css", "option"),
  function(column) column$clickElement()
)
# click "< Add to display list"
browser $
  findElement(using = "css", ".columnPicker .columnPicker :nth-child(5) input") $
  clickElement()
# click "Save & Return"
browser $
  findElement(using = "css", "#Submit1") $
  clickElement()
# wait for page to load
Sys.sleep(15)

all_countries = codelist$country.name.en

# search the names of all countries
# sometimes this will fail part-way through because the server gets overwhelmed
# to wait a few hours and try again
walk(all_countries, function(country) get_country(browser, country))

browser$close()

# useful to resume from a certain country
# so you don't have to start all over
# for example
# walk(from(all_countries, "St. Lucia"), function(country) get_country(browser, country))
from = function(all_countries, first_country) { # nolint
  all_countries[which(first_country == all_countries):length(all_countries)]
}

# To debug
# browser$screenshot(display = TRUE, useViewer = FALSE)
