library(countrycode)
library(purrr)
library(readr)
library(RSelenium)
library(XML)


# before you run RSelenium, you need to pull and open the docker image:
# sudo docker pull selenium/standalone-firefox
# sudo docker run --detach --publish 4445:4444 selenium/standalone-firefox
# when you are done, close all docker images:
# sudo docker stop (sudo docker ps --quiet)
browser = remoteDriver(port = 4445)
browser$open()

# extract the table from the website
get_table = function(browser) {
  table = 
    browser$getPageSource() %>%
    .[[1]] %>%
    htmlParse %>%
    readHTMLTable(stringsAsFactors = FALSE) %>%
    .[["_ctl0_MainContent_TabContainer1_TabPanel1_dgEmployees"]]
  names(table) = as.character(table[1,])
  table[-1, ]
}

searches = list()
country = "Korea"
get_country = function(browser, country, load_time = 10) {
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
  Sys.sleep(load_time)
  
  searches[[paste(country, 0)]] <<- get_table(browser)
  
  extra_pages = browser$findElements(using = "css", "tr:nth-child(22) a")
  if (length(extra_pages) > 0) {
    for (i in 1:length(extra_pages)) {
      extra_pages[[i]]$clickElement()
      message(paste("Loading page", i))
      Sys.sleep(load_time)
      # now we're on a new page, relist pages
      extra_pages = browser$findElements(using = "css", "tr:nth-child(22) a")
      # the ith page listed will always refer to the next page
      # X 2 3, i = 1 is page 2
      # 1 X 3, i = 2 is page 3
      searches[[paste(country, i)]] <<- get_table(browser)
    }
  }
}

# run just once to save all the columns
get_country(browser, "Sudan")
# click "Pick Columns to Display(Sort by)"
browser $
  findElement(using = "css", "a:nth-child(4)") $
  clickElement()
# click all columns
walk(browser$findElements(using = "css", "option"), function(column) column$clickElement())
# click "< Add to display list"
browser $
  findElement(using = "css", ".columnPicker .columnPicker :nth-child(5) input") $
  clickElement()
# click "Save & Return"
browser $
  findElement(using = "css", "#Submit1") $
  clickElement()
Sys.sleep(10)

# search the names of all countries
walk(codelist$country.name.en, function(country) get_country(browser, country))

bind_rows(searches) %>%
  # remove duplicate rows
  unique %>%
  write_csv("cost_effectiveness.csv")