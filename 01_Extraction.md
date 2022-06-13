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

## Check to see if data is up to date. If not, download latest data.

### Data sources:

-   [Our World in
    Data](https://covid.ourworldindata.org/data/owid-covid-data.csv)
-   [The Oxford COVID-19 Government Response
    Tracker](https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv)
-   [Average latitude & longitude for
    Countries](https://raw.githubusercontent.com/albertyw/avenews/master/old/data/average-latitude-longitude-countries.csv)

``` r
#function to check if latest csv file exists. If not, to download it. 
download_csv <- function(csv_name,url){
  
  dest <- paste0("./",csv_name) 
  
  if (!file.exists(csv_name)){
  download.file(url,
                destfile = dest, mode = "wb")
} else if (file.exists(dest)
           && format(file.info(csv_name)$mtime,'%Y-%m-%d') != format(Sys.time(),'%Y-%m-%d'))
{
  download.file(url,
                destfile = dest, mode = "wb")
}else{
  print(paste0(csv_name, ' is up to date'))
}
}

#call functions to download data
download_csv("owid-covid-data.csv",
             "https://covid.ourworldindata.org/data/owid-covid-data.csv")
```

    ## [1] "owid-covid-data.csv is up to date"

``` r
download_csv('OxCGRT_latest.csv',
             "https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv")
```

    ## [1] "OxCGRT_latest.csv is up to date"

``` r
download_csv('average-latitude-longitude-countries.csv',
             "https://raw.githubusercontent.com/albertyw/avenews/master/old/data/average-latitude-longitude-countries.csv")
```

    ## [1] "average-latitude-longitude-countries.csv is up to date"

# Import raw data into data frames

``` r
#import latest oxford data into dataframe
ox_raw <- fread("OxCGRT_latest.csv",stringsAsFactors = TRUE) %>% as_tibble()
ox_df <- ox_raw %>% filter(Jurisdiction == "NAT_TOTAL")

colnames(ox_df)[6] <- 'date'
colnames(ox_df)[1] <- 'location'
colnames(ox_df)[2] <- 'iso_code'
ox_df$date <- as.character(ox_df$date)
ox_df$date <- as.Date(ox_df$date, '%Y%m%d')
names(ox_df) <- tolower(gsub("([a-z1-9])([A-Z])", "\\1_\\2", names(ox_df)))
ox_df$location <- gsub("Slovak Republic","Slovakia",ox_df$location)
ox_df$location <- gsub("Czech Republic","Czechia",ox_df$location)
ox_df$location <- gsub("Kyrgyz Republic","Kyrgyzstan",ox_df$location)
names(ox_df) <- gsub(" ", "_", names(ox_df))


#import owid data 
cv_raw <- fread("owid-covid-data.csv",stringsAsFactors = TRUE) %>% as_tibble()
cv_raw <- cv_raw %>% select(-c(tests_units,stringency_index))


#import latitude data and select columns with location, latitude, and longitude
lat <- fread("average-latitude-longitude-countries.csv",stringsAsFactors = TRUE) %>% as_tibble() %>% select(2:4)
#rename columns of latitude data for database consistency
colnames(lat) <- c('location','lat_raw','long_raw') 
names(lat) <- tolower(names(lat))
lat$location <- gsub("Czech Republic","Czechia",lat$location)
lat$location <- gsub("Iran, Islamic Republic of","Iran",lat$location)
lat$location <- gsub("Korea, Democratic People's Republic of","North Korea",lat$location)
lat$location <- gsub("Korea, Republic of","South Korea",lat$location)
lat$location <- gsub("Moldova, Republic of","Moldova",lat$location)
lat$location <- gsub("Syrian Arab Republic","Syria",lat$location)
lat$location <- gsub("Tanzania, United Republic of","Tanzania",lat$location)
lat$location <- gsub("Lao People's Democratic Republic","Lao",lat$location)

ox_country_list <- ox_df %>% filter(date == "2020-12-30") %>% select(location,iso_code)
cv_country_list <- cv_raw %>%  filter(date == "2020-12-30") %>%  select(location,iso_code)
lat_country_list <- lat$location %>% as_tibble()

#merge oxford and owid data
df <- merge(cv_raw, ox_df, by = c('iso_code','location','date'))

#merge main dataframe with latitude data frame
df <- merge(df, lat, by = 'location')

#create new column removing negative sign form latitude / long data
df <- df %>% mutate(latitude = abs(lat_raw), longitude = abs(long_raw))

# arrange main dataframe by location then date in ascending order
df <- df %>%  arrange(location, date)

#create restriction cubed columns
df <- df %>% 
  group_by(location) %>%  
  mutate(c2_workplace_closing_cubed = c2_workplace_closing ^ 3,
         c6_stay_at_home_requirements_cubed = c6_stay_at_home_requirements ^ 3,
         c7_restrictions_on_internal_movement_cubed = c7_restrictions_on_internal_movement ^ 3,
         h6_facial_coverings_cubed = h6_facial_coverings ^ 3)

#create cumulative sum columns of restriction variables
df  <- df %>% 
  group_by(location) %>%  
  mutate(cum_c2_workplace_closing = cumsum(replace_na(c2_workplace_closing,0)),
         cum_c6_stay_at_home_requirements = cumsum(replace_na(c6_stay_at_home_requirements,0)),
         cum_c7_restrictions_on_internal_movement = cumsum(replace_na(c7_restrictions_on_internal_movement,0)),
         cum_h6_facial_coverings = cumsum(replace_na(h6_facial_coverings,0)),
         cum_c2_workplace_closing_cubed = cumsum(replace_na(c2_workplace_closing_cubed,0)),
         cum_c6_stay_at_home_requirements_cubed = cumsum(replace_na(c6_stay_at_home_requirements_cubed,0)),
         cum_c7_restrictions_on_internal_movement_cubed  = cumsum(replace_na(c7_restrictions_on_internal_movement_cubed ,0)),
         cum_h6_facial_coverings_cubed  = cumsum(replace_na(h6_facial_coverings_cubed ,0)
         )
  )
#create total restrictions columns by summing all other restriction variables
df  <- df %>% 
  group_by(location) %>% 
  mutate(
    total_restrictions = cum_c2_workplace_closing + cum_c6_stay_at_home_requirements + 
      cum_c7_restrictions_on_internal_movement + cum_h6_facial_coverings,
    total_restrictions_cubed = cum_c2_workplace_closing_cubed + cum_c6_stay_at_home_requirements_cubed + 
      cum_c7_restrictions_on_internal_movement_cubed + cum_h6_facial_coverings_cubed)

#sanity check to make sure there is only one row per date
df_check <- df %>% count(location,date)
print(paste0("The unique count of each date is: ", max(df_check$n)))
```

    ## [1] "The unique count of each date is: 1"

# Calculate first_date_death and max / ave stringency

``` r
#helper filtering function to filter date and contienent
df_date <- function(df, dt){
  
  df <- df %>% filter(date == dt)
  
  return(df)
}

df_country <- function(df, cty){
  
  df <- df %>% filter(location == cty)
  
  return(df)
}

df_continent <- function(df, cnt){
  
  df <- df %>% filter(continent == cnt)
  
  return(df)
}




#find max stringency index and populate new column

#helper function to find max stringency 
find_max_stringency <- function(ct,dt){
  output <- df %>% 
    ungroup() %>%
    filter(location == ct & date <= dt) %>%
    select(stringency_index) %>% 
    max(na.rm = TRUE) 
  return (output)
} 

#helper function to find date first death occurred
find_date_first_death <- function(ct){
  output <- df %>% 
    ungroup() %>%
    filter(location == ct) %>% 
    filter(total_deaths == new_deaths | total_deaths == 1 & new_deaths == 1) %>% 
    select(date) %>% 
    pull() %>% as.Date('%Y%m%d')
  return (output)
}

df_first_date <- df %>% group_by(location) %>% summarise(first_death_date = find_date_first_death(location))

#merge first death date into main dataframe
df <- merge(df, df_first_date, by = 'location')

df <- df %>% mutate(date_first_death_days = as.numeric(difftime(first_death_date, "2020-02-15"), unit = 'days'))


#find max stringency
df_max_si <- df %>% group_by(location) %>% summarise(max_stringency = find_max_stringency(location,max(df$date) %>% as.character()))

df_max_si_europe_20201230 <- df %>% group_by(location) %>% summarise(max_stringency = find_max_stringency(location,"2020-12-30"))

df_max_si_europe_20211230 <- df %>% group_by(location) %>% summarise(max_stringency = find_max_stringency(location,"2021-12-30"))

df_max_si_europe_20220520 <- df %>% group_by(location) %>% summarise(max_stringency = find_max_stringency(location,"2022-05-20"))

df_large <- merge(df, df_max_si, by = 'location')

df_europe <- df_continent(df, "Europe")
df_europe_20201230 <- df_date(df_europe,"2020-12-30")
df_europe_20201230_large <- merge(df_europe_20201230, df_max_si_europe_20201230, by = 'location')

df_europe_20211230 <- df_date(df_europe,"2021-12-30")
df_europe_20211230_large <- merge(df_europe_20211230, df_max_si_europe_20211230, by = 'location')

df_europe_20220520 <- df_date(df_europe,"2022-05-20")
df_europe_20220520_large <- merge(df_europe_20220520, df_max_si_europe_20220520, by = 'location')
```

# Create filtered version of data for exporting

``` r
#create filtered data frame to output to  csv

small_column_list <- c("iso_code","continent","location","date","c2_workplace_closing","c2_workplace_closing_cubed","cum_c2_workplace_closing","cum_c2_workplace_closing_cubed","c6_stay_at_home_requirements","c6_stay_at_home_requirements_cubed","cum_c6_stay_at_home_requirements","cum_c6_stay_at_home_requirements_cubed","c7_restrictions_on_internal_movement","c7_restrictions_on_internal_movement_cubed","cum_c7_restrictions_on_internal_movement","cum_c7_restrictions_on_internal_movement_cubed","h6_facial_coverings","h6_facial_coverings_cubed","cum_h6_facial_coverings","cum_h6_facial_coverings_cubed","total_restrictions","total_restrictions_cubed","new_deaths_per_million","total_deaths_per_million","stringency_index_for_display","government_response_index_for_display","containment_health_index_for_display","economic_support_index_for_display","date_first_death_days","max_stringency","population_density")

df_small <- df_large %>% select(small_column_list)
df_europe_20201230_small <- df_europe_20201230_large %>% select(small_column_list) %>% select(-c("new_deaths_per_million")) 
df_europe_20211230_small <- df_europe_20211230_large %>% select(small_column_list) %>% select(-c("new_deaths_per_million")) 
df_europe_20220520_small <- df_europe_20220520_large %>% select(small_column_list) %>% select(-c("new_deaths_per_million"))
```

## Sort data by country and date

``` r
#arrange all dataframes by location then date in asccending order
df_large <- df_large %>% arrange(location,date)
df_small <- df_small %>% arrange(location,date)

df_europe_20201230_large <- df_europe_20201230_large %>% arrange(location,date)
df_europe_20201230_small <- df_europe_20201230_small %>% arrange(location,date)

df_europe_20211230_large <- df_europe_20211230_large %>% arrange(location,date)
df_europe_20211230_small <- df_europe_20211230_small %>% arrange(location,date)

df_europe_20220520_large <- df_europe_20220520_large %>% arrange(location,date)
df_europe_20220520_small <- df_europe_20220520_small %>% arrange(location,date)
```

## Save data as RDS files

``` r
saveRDS(df_large, file = "OxOw_Extraction_large.rds")
saveRDS(df_small, file = "OxOw_Extraction_small.rds")

saveRDS(df_europe_20201230_large, file = "OxOw_Extraction_europe_20201230_large.rds")
saveRDS(df_europe_20201230_small, file = "OxOw_Extraction_europe_20201230_small.rds")

saveRDS(df_europe_20211230_large, file = "OxOw_Extraction_europe_20211230_large.rds")
saveRDS(df_europe_20211230_small, file = "OxOw_Extraction_europe_20211230_small.rds")

saveRDS(df_europe_20220520_large, file = "OxOw_Extraction_europe_20220520_large.rds")
saveRDS(df_europe_20220520_small, file = "OxOw_Extraction_europe_20220520_small.rds")
```

## Cleanup workspace

``` r
#cleanup workspace
rm(list=setdiff(ls(), c("df_large","df_small",
                        "df_europe_20201230_large",
                        "df_europe_20201230_small",
                        "df_europe_20211230_large",
                        "df_europe_20211230_small",
                        "df_europe_20220520_large",
                        "df_europe_20220520_small")))
```