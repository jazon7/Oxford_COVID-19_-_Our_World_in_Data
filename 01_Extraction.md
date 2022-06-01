Covid Data and Restrictions - Extraction
================

Load required packages

``` r
if (!require(pacman)) install.packages('pacman')
library(pacman)
p_load(tidyverse,readxl,lubridate,data.table,scales)
#remove scientific notation and warnings
options(scipen=999)
options(warn=-1)
```

Check to see if data is up to date. If not, download latest data.

Data sources:

-   [Our World in
    Data](https://covid.ourworldindata.org/data/owid-covid-data.csv)
-   [The Oxford COVID-19 Government Response
    Tracker](https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv)
-   [Average latitude & longitude for
    Countries](https://raw.githubusercontent.com/albertyw/avenews/master/old/data/average-latitude-longitude-countries.csv)

``` r
if (!file.exists('owid-covid-data.csv')){
  download.file("https://covid.ourworldindata.org/data/owid-covid-data.csv",
                destfile = "./owid-covid-data.csv", mode = "wb")
} else if (file.exists('owid-covid-data.csv')
           && format(file.info('owid-covid-data.csv')$mtime,'%Y-%m-%d') != format(Sys.time(),'%Y-%m-%d'))
{
  download.file("https://covid.ourworldindata.org/data/owid-covid-data.csv",
                destfile = "./owid-covid-data.csv", mode = "wb")
}else{
  print('No need to download')
}
```

    ## [1] "No need to download"

``` r
if (!file.exists('OxCGRT_latest.csv')){
  download.file("https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv",
                destfile = "./OxCGRT_latest.csv", mode = "wb")
} else if (file.exists('OxCGRT_latest.csv')
           && format(file.info('OxCGRT_latest.csv')$mtime,'%Y-%m-%d') != format(Sys.time(),'%Y-%m-%d'))
{
  download.file("https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv",
                destfile = "./OxCGRT_latest.csv", mode = "wb")
}else{
  print('No need to download')
}
```

    ## [1] "No need to download"

``` r
#download latitude data from github
if (!file.exists('average-latitude-longitude-countries.csv')){
  download.file("https://raw.githubusercontent.com/albertyw/avenews/master/old/data/average-latitude-longitude-countries.csv",
                destfile = "./average-latitude-longitude-countries.csv", mode = "wb")
}
```

Import and cleanup Oxford Covid Government Tracker data

``` r
ox <- fread("OxCGRT_latest.csv",stringsAsFactors = TRUE)
#filter data for National Total only (remove State data)
ox <- ox %>% filter(Jurisdiction == "NAT_TOTAL")
#create vector of salient variables
filt_cols_ox <- c("CountryName", "Date", 
                  "C2_Workplace closing",
                  "C6_Stay at home requirements",
                  "C7_Restrictions on internal movement",
                  "H6_Facial Coverings")
#new dataframe filtered by salient variables
ox_f <- ox %>% select(filt_cols_ox) 
#convert date column into date format
ox_f$Date <- as.character(ox_f$Date)
ox_f$Date <- as.Date(ox_f$Date, '%Y%m%d')
#sort the data by location and date
ox_f <- ox_f %>%  arrange(CountryName, ymd(ox_f$Date))
#rename CountryName and date as location and date_col
colnames(ox_f)[1] <- 'location'
colnames(ox_f)[2] <- 'date_col'
#replace spaces with underscore in column names
colnames(ox_f) <- gsub(" ", "_", colnames(ox_f))
#convert column names to lower case
names(ox_f) <- tolower(names(ox_f))
#sum restriction across dates thus leaving only one single value per date
ox_df <- ox_f %>%
  mutate(date = date(date_col)) %>% 
  group_by(location, date) %>% 
  summarise(c2_workplace_closing = sum(c2_workplace_closing, na.rm = TRUE),
            c6_stay_at_home_requirements = sum(c6_stay_at_home_requirements, na.rm = TRUE),
            c7_restrictions_on_internal_movement = sum(c7_restrictions_on_internal_movement, na.rm = TRUE),
            h6_facial_coverings = sum(h6_facial_coverings, na.rm = TRUE))
#create a cumulative sum column for each variable replacing NA with zero
ox_df  <- ox_df %>% 
  group_by(location) %>%  
  mutate(cum_c2_workplace_closing = cumsum(replace_na(c2_workplace_closing,0)),
         cum_C6_stay_at_home_requirements = cumsum(replace_na(c6_stay_at_home_requirements,0)),
         cum_C7_restrictions_on_internal_movement = cumsum(replace_na(c7_restrictions_on_internal_movement,0)),
         cum_H6_facial_coverings = cumsum(replace_na(h6_facial_coverings,0)))
#create total restrictions columns by summing all other restriction variables
ox_df  <- ox_df %>% 
  group_by(location) %>% 
  mutate(
    total_restrictions = cum_c2_workplace_closing + cum_C6_stay_at_home_requirements + 
      cum_C7_restrictions_on_internal_movement + cum_H6_facial_coverings)

ox_df <- ox_df %>%
  mutate(
    total_restrictions_squared = total_restrictions * total_restrictions
  )
```

Import and cleanup owid covid and latitude data

``` r
#import owid data 
cv_raw <- fread("owid-covid-data.csv",stringsAsFactors = TRUE) %>% as_tibble()
#import latitude data and select columns with location, latitude, and longitude
lat <- fread("average-latitude-longitude-countries.csv",stringsAsFactors = TRUE) %>% select(2:4)
#rename column names of latitude data
colnames(lat) <- c('location','latitude','longitude')

#merge owid and latitude data frames
cv_raw <- merge(cv_raw, lat, by = 'location')
#sort data by date  (ascending)
cv_raw <- cv_raw %>% arrange(date)
#drop test unit and iso code columns
cv_raw <- cv_raw %>% select(-c(tests_units,iso_code))
#create positive absolute function latitude (to remove negative values)
cv_raw$latitude <- abs(cv_raw$latitude)
#merge owid and oxford data
df <- merge(cv_raw, ox_df, by = c('location', 'date'))
```

Cleanup workspace

``` r
#cleanup workspace
rm(list=setdiff(ls(), "df"))
```

Create filtered data frame with only restriction and covid death
variables

``` r
#create filtered data frame to output to  csv
df_small <- df %>% select(continent, location, date, 
                  c2_workplace_closing,
                  cum_c2_workplace_closing,
                  c6_stay_at_home_requirements,
                  cum_C6_stay_at_home_requirements,
                  c7_restrictions_on_internal_movement,
                  cum_C7_restrictions_on_internal_movement,
                  h6_facial_coverings,
                  cum_H6_facial_coverings,
                  total_restrictions,
                  total_restrictions_squared,
                  new_deaths_per_million,
                  total_deaths_per_million
                  )
```

Save data as RDS files

``` r
saveRDS(df, file = "OxOw_Extraction_large.rds")
saveRDS(df_small, file = "OxOw_Extraction_small.rds")
```