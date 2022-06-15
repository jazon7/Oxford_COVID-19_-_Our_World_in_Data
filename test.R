if (!require(pacman)) install.packages('pacman')
library(pacman)
p_load(tidyverse,readxl,lubridate,data.table,scales,viridis,ggthemes,ggrepel)
#remove scientific notation and warnings
options(scipen=999)
options(warn=-1)



post <- "https://github.com/owid/covid-19-data/tree/master/public/data"
ref_1 <- "https://www.nature.com/articles/s41562-021-01122-8"
ref_2 <- "https://www.nature.com/articles/s41597-020-00688-8"


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
download_csv('OxCGRT_latest.csv',
             "https://raw.githubusercontent.com/OxCGRT/covid-policy-tracker/master/data/OxCGRT_latest.csv")
download_csv('average-latitude-longitude-countries.csv',
             "https://raw.githubusercontent.com/albertyw/avenews/master/old/data/average-latitude-longitude-countries.csv")

download_csv("owid-obesity.csv","https://raw.githubusercontent.com/camminady/overweight/master/share-of-adults-defined-as-obese.csv")

# Import raw data into data frames
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

obe <- fread("owid-obesity.csv",stringsAsFactors = TRUE) %>% as_tibble()
names(obe)
obe <- obe %>% 
  filter(Year == max(obe$Year)) %>% 
  rename(obesity_prevalence = `Indicator:Prevalence of obesity among adults, BMI &GreaterEqual; 30 (age-standardized estimate) (%) - Age Group:18+  years - Sex:Both sexes (%)`,
         location = Entity, iso_code = Code) %>% 
  select(-c("Year","location"))
#merge oxford and owid data
df <- merge(cv_raw, ox_df, by = c('iso_code','location','date'))

#merge main dataframe with latitude data frame
df <- merge(df, lat, by = 'location')

#merge main dataframe with obesity data frame
df <- merge(df, obe, by = 'iso_code')

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

# Calculate first_date_death and max / ave stringency
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



#world data

df_filtered <- function(df,date){
  
  df_max_si <- df %>% group_by(location) %>% summarise(max_stringency = 
                                                         find_max_stringency(location,date))
  
  df_a <- df_date(df,date)
  df_out <- merge(df_a, df_max_si, by = 'location') %>% arrange(location,date)
  
  return(df_out)
  
}

df  <- df_filtered(df,"2021-12-30") 



corr_table <- function(df){
  date <- df$date[1]
  tble <- df[,unlist(lapply(df, is.numeric))] %>% correlate() %>% focus(total_deaths_per_million) %>% 
    rename(Variable = term) %>% arrange(total_deaths_per_million) %>%  
    kbl(caption = paste0("Correlation - World - Total deaths per million - ",date)) %>% 
    kable_classic(full_width = F)
  
  return(tble)
}

corr_plot <- function (df){
  date <- df$date[1]
  plot <- df[,unlist(lapply(df, is.numeric))] %>% correlate() %>% focus(total_deaths_per_million) %>% 
    mutate(term = factor(term, levels = term[order(total_deaths_per_million)])) %>%
    ggplot(aes(x = term, y = total_deaths_per_million)) +
    geom_bar(stat = "identity", fill = 'purple') +
    ylab("Total deaths per million (corr)") +
    xlab("") +
    ylim(c(-1,1)) +
    ggtitle(paste0("Correlation - World - ",date)) +
    theme_classic2() +
    theme(axis.text.x=element_text(angle=75,hjust=1,vjust=1))
  
  return(plot)
  
}

corr_matrix <- function(df){
  date <- df$date[1]
  corPlot(df[,unlist(lapply(df, is.numeric))],
          min.length = 15,
          scale = FALSE,
          diag = FALSE,
          upper = FALSE,
          alpha = 0.20,
          stars = TRUE,
          cex = 0.5,
          cex.axis = 0.5,
          xlas = 2,
          main = paste0("Correlations - World -  ",date),
  )
  
}

create_metric_list <- function(df){
  metric_choices <- colnames(df)
  metric_names <- gsub("_", " ", metric_choices)
  metric_names <- paste0(toupper(substr(metric_names, 1,1)), substr(metric_names,2, nchar(metric_names)))
  metric_list <- as.list(metric_choices)
  names(metric_list) <- metric_names
  return (metric_list)
}

country_scatter_list <- create_metric_list(df)

#function to plot scatter plot 
country_scatter <- function(df_input, x_metric) {
  
  if(df_input %>% select(x_metric) %>% min(na.rm = T) >=1){
    min_x <- df_input %>% select(x_metric) %>% min(na.rm = T)
  }
  else{
    min_x <- df_input %>% select(x_metric) %>% min(na.rm = T)
  }
  
  max_x <- df_input %>% select(x_metric) %>% max(na.rm = T)
  max_y <- df_input %>% select('total_deaths_per_million') %>% max(na.rm = T)

  date <- df_input %>% select(date) %>% filter(row_number()==1) %>% pull()
  plot <- df_input %>% 
    ggplot(aes_string(x = x_metric, y = "total_deaths_per_million", label = "location")) +
    geom_point(data = df_input, aes(color = continent)) +
    geom_smooth(method = lm, se = F, colour = 'grey') +
    scale_size_continuous(range = c(2,10)) +
    scale_color_viridis(discrete = TRUE, option = 'C') +
    geom_text_repel(max.overlaps = 10, size = 3) +
    annotate("text", label= paste0("R = ", round(with(df_input,
                                                              cor.test(total_deaths_per_million, get(x_metric), method = "pearson"))$estimate, 2),", p = ", 
                                           round(with(df_input,cor.test(total_deaths_per_million, get(x_metric), method = "pearson"))$p.value, 3),
                                           ", n = ", nrow(df_input)),x = min_x + (0.10 * (max_x - min_x)), y = max_y, color = "red", size = 3) +
    labs(color = "Continent") +
    ylab("Total deaths per million") +
    xlab(x_metric) +
    ggtitle(paste0("Total deaths per million vs ", x_metric, " as of ", date)) +
    guides(color = guide_legend(override.aes = list(size = 7))) +
    theme_minimal()+
    theme(axis.title = element_text(size = 14, family="serif"),
          axis.text = element_text(size = 12, family="serif"),
          legend.title = element_text(size = 13,family="serif"),
          legend.text = element_text(size = 10,family="serif"),
          plot.title = element_text(size = 14, family="serif"),
          plot.title.position = 'plot'
    )
  return(plot)
}

country_scatter(df,"total_restrictions_cubed")
