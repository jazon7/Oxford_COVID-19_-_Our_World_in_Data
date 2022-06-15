
if (!require(pacman)) install.packages('pacman')
library(pacman)
p_load(tidyverse,readxl,lubridate,data.table,scales,shiny,shinyWidgets,
       plotly,ggthemes,data.table,grid,gridExtra,DT,bslib,showtext,ggrepel
)
#remove scientific notation and warnings
options(scipen=999)
options(warn=-1)


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

#helper function to find max stringency
set_max_si <- function(df_input,date_input){
  df_input <- df_input %>% select(-max_stringency)
  print(date_input)
  df_max_si <- df_input %>% group_by(location) %>% 
    summarise(max_stringency = find_max_stringency(location,date_input) %>% 
                as.character())
  
  df_out <- merge(df_input, df_max_si, by = 'location') %>% 
    arrange(location,date)
  
  return(df_out)
}

df_first_date <- df %>% group_by(location) %>% summarise(first_death_date = find_date_first_death(location))

#merge first death date into main dataframe
df <- merge(df, df_first_date, by = 'location')
df <- df %>% mutate(date_first_death_days = as.numeric(difftime(first_death_date, "2020-02-15"), unit = 'days'))
df <- df %>% mutate(max_stringency = NA)

#funciton to create list of column names for labels
create_metric_list <- function(df){
  metric_choices <- colnames(df)
  metric_names <- gsub("_", " ", metric_choices)
  metric_names <- paste0(toupper(substr(metric_names, 1,1)), substr(metric_names,2, nchar(metric_names)))
  metric_list <- as.list(metric_choices)
  names(metric_list) <- metric_names
  return (metric_list)
}


cv_raw <- set_max_si(df,max(df$date))

post <- "https://github.com/owid/covid-19-data/tree/master/public/data"
ref_1 <- "https://www.nature.com/articles/s41562-021-01122-8"
ref_2 <- "https://www.nature.com/articles/s41597-020-00688-8"


#funciton to create list of column names for labels
create_metric_list <- function(df){
  metric_choices <- colnames(df)
  metric_names <- gsub("_", " ", metric_choices)
  metric_names <- paste0(toupper(substr(metric_names, 1,1)), substr(metric_names,2, nchar(metric_names)))
  metric_list <- as.list(metric_choices)
  names(metric_list) <- metric_names
  return (metric_list)
}

#create lists
time_series_list <- create_metric_list(cv_raw %>% select(contains(c('per_million','per_hundred', 'per_thousand', 'per_case')) | contains('rate')) %>%
                                         select(!contains("mortality")) %>% 
                                         select(!contains("smoothed")) %>% 
                                         select(!c("cardiovasc_death_rate","hospital_beds_per_thousand")) %>% 
                                         select("new_deaths_per_million", sort(colnames(.))))

time_series_colour_list <- create_metric_list(cv_raw %>% select(people_fully_vaccinated_per_hundred,
                                                                people_vaccinated_per_hundred,
                                                                total_boosters_per_hundred,
                                                                stringency_index))

metric_smoothed_list <- create_metric_list(cv_raw %>% select(contains(c("smoothed",'total'))))

country_scatter_list <- create_metric_list(cv_raw %>% select(contains(c('per_million','per_hundred',"population_density",
                                                                                "median_age","gdp_per_capita","extreme_poverty",
                                                                                "cardiovasc_death_rate","diabetes_prevalence",
                                                                                "life_expectancy","human_development_index",
                                                                                "latitude","total_restrictions",
                                                                                "total_restrictions_cubed","first_death_date",
                                                                                "date_first_death_days","max_stringency",
                                                                                "obesity_prevalence"))) %>%
                                             select(!contains("mortality")) %>%
                                             select(!contains("weekly")) %>%
                                             select("total_deaths_per_million", "total_cases_per_million", sort(colnames(.))))

metric_per_list <- create_metric_list(cv_raw %>% select(contains("per")))

cv_raw_list <- create_metric_list(cv_raw)
cv_raw_per_list <- create_metric_list(cv_raw %>% select(contains(c("per_million", "per_thousand", 'per_case', 'per_hundred'))))


#ui***************************************************************
ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "darkly",
                          base_font = bslib::font_google("Open Sans")),
  
  titlePanel("Covid 19 Data"),
  
  tabsetPanel(
    tabPanel("Time Series",fluid = T,
             sidebarLayout(
               sidebarPanel = sidebarPanel(
                 
                 selectizeInput('country', 'Country',
                                choices = sort(unique(cv_raw$location)),
                                
                                selected = "United States"),
                 
                 selectizeInput('y', 'Metric', 
                                choices = time_series_list, 
                                
                                selected = time_series_list[1]),
                 
                 selectizeInput('colour', 'Colour',
                                choices = time_series_colour_list,
                                
                                selected = time_series_colour_list[1]),
                 
                 
                 materialSwitch(inputId = "vaccine_start_check", label = "Vaccine Rollout Date", value = FALSE, status = 'info'),
                 
                 materialSwitch(inputId = "free_y_axis", label = "Optimise scale", value = FALSE,status = 'info'),
                 
                 sliderInput("smoothing",
                             "Smoothing line:",
                             min = 0.1,
                             max = 0.9,
                             step = 0.1,
                             ticks = F,
                             label = 'Smoothing',
                             value = 0.3),
                 
                 tags$div(tags$p(HTML("<br><br>
                       Data source: ")),
                       tags$a(href=post, "Our World in Data")),
                 
                 
                 
                 tags$div(tags$p(HTML("<br>
                       References: ")),
                       tags$a(href=ref_1, "Mathieu et al."),
                       tags$a(href=ref_1 , "Hassell et al.")),
                 
                 width = 3),
               mainPanel(
                 plotlyOutput("cvPlot", width = '90%',height = 700)
                 
               )
               
             )
             
    ),
    tabPanel("Scatterplot",fluid = T,
             sidebarLayout(
               sidebarPanel = sidebarPanel(
                 
                 selectizeInput('country_scatter', 'Country',
                                choices = sort(unique(cv_raw$location)),
                                
                                selected = "United States"),
                 
                 selectizeInput('y_axis', 'Y Axis', 
                                choices = time_series_list, 
                                
                                selected = time_series_list[1]),
                 
                 selectizeInput('x_axis', 'X Axis',
                                choices = time_series_list,
                                
                                selected = time_series_list[6]),
                 
                 
                 sliderInput("smoothing_scatter",
                             "Smoothing line:",
                             min = 0.1,
                             max = 0.9,
                             step = 0.1,
                             ticks = F,
                             label = 'Smoothing',
                             value = 0.9),
                 
                 switchInput(inputId = "linear", label = "Linear", value = FALSE),
                 
                 tags$div(tags$p(HTML("<br><br><br><br>
                       Data source: ")),
                       tags$a(href=post, "Our World in Data")),
                 
                 
                 
                 tags$div(tags$p(HTML("<br>
                       References: ")),
                       tags$a(href=ref_1, "Mathieu et al."),
                       tags$a(href=ref_1 , "Hassell et al.")),
                 
                 width = 3),
               mainPanel(
                 plotlyOutput('scatterPlot',width = '90%',height = 690)
                 
                 
               )
               
             )
    ),
    tabPanel("Data Tables",fluid = T,
             sidebarLayout(
               sidebarPanel = sidebarPanel(
                 
                 selectizeInput('country_data', 'Country',
                                choices = sort(unique(cv_raw$location)),
                                
                                selected = "United States"),
                 
                 tags$div(tags$p(HTML("<br><br><br><br>
                       Data source: ")),
                       tags$a(href=post, "Our World in Data")),
                 
                 
                 
                 tags$div(tags$p(HTML("<br>
                       References: ")),
                       tags$a(href=ref_1, "Mathieu et al."),
                       tags$a(href=ref_1 , "Hassell et al.")),
                 
                 width = 3),
               mainPanel(
                 tabsetPanel(type = 'tabs',
                             tabPanel('Covid Data', dataTableOutput("country_table")),
                             tabPanel('Demographics', dataTableOutput("country_dem"))
                 ))
               
             )
    ),
    tabPanel("Country Comparison",fluid = T,
             sidebarLayout(
               sidebarPanel = sidebarPanel(
                 
                 conditionalPanel(condition="input.tabselected==1", 
                                  
                                  selectizeInput('country_compare', 'Select Countries to Compare',
                                                 multiple = TRUE, 
                                                 choices = sort(unique(cv_raw$location)),
                                                 
                                                 selected = c("United States", "United Kingdom", "Israel", "Sweden")),
                                  
                                  selectizeInput('metric_compare', 'Metric', 
                                                 choices = metric_smoothed_list, 
                                                 
                                                 selected = metric_smoothed_list[4]),
                                  
                                  dateRangeInput(
                                    "date_range_country", "Select Date Range:",
                                    start = "2020-01-01",
                                    end = Sys.Date(),
                                    
                                  ),
                                  
                                  tags$div(tags$p(HTML("<br><br>
                       Data source: ")),
                       tags$a(href=post, "Our World in Data")),
                       
                       
                       
                       tags$div(tags$p(HTML("<br>
                       References: ")),
                       tags$a(href=ref_1, "Mathieu et al."),
                       tags$a(href=ref_1 , "Hassell et al.")),
                       
                 ),
                 
                 conditionalPanel(condition = "input.tabselected==2", selectizeInput('continent', 'Select Countries by Continent',
                                                                                     multiple = TRUE, 
                                                                                     choices = sort(unique(cv_raw$continent)),
                                                                                     
                                                                                     selected = unique(cv_raw$continent)),
                                  
                                  selectizeInput('y_metric', 'y Metric',
                                                 choices = country_scatter_list,
                                                 
                                                 selected = country_scatter_list[1]),
                                  
                                  
                                  selectizeInput('x_metric', 'x Metric',
                                                 choices = country_scatter_list,
                                                 
                                                 selected = country_scatter_list[3]),
                                  
                                  selectizeInput('size_metric', 'Size Metric',
                                                 choices = country_scatter_list,
                                                 
                                                 selected = country_scatter_list[20]),
                                  
                                  
                                  
                                  dateInput(
                                    "date_select", "Select Date:",
                                    min = "2020-01-01",
                                    max = Sys.Date() - 5,
                                    value = Sys.Date() - 5,
                                    
                                  ),
                                  
                                  sliderInput("smoothing_country",
                                              "Smoothing line:",
                                              min = 0.1,
                                              max = 0.9,
                                              step = 0.1,
                                              ticks = F,
                                              label = 'Smoothing',
                                              value = 0.9),
                                  
                                  switchInput(inputId = "linear_country", label = "Linear", value = TRUE),
                                  
                                  
                                  tags$div(tags$p(HTML("<br><br>
                       Data source: ")),
                       tags$a(href=post, "Our World in Data")),
                       
                       
                       
                       tags$div(tags$p(HTML("<br>
                       References: ")),
                       tags$a(href=ref_1, "Mathieu et al."),
                       tags$a(href=ref_1 , "Hassell et al."))
                       
                 )
                 
                 ,width = 3),
               
               mainPanel(
                 tabsetPanel(type = 'tabs', id = 'tabselected',
                             tabPanel("Time Series", value = 1,  plotOutput("country_compare", width = "90%", height = 700)),
                             tabPanel("Scatterplot", value = 2,  plotOutput("country_scatter", width = "90%", height = 700)),
                             
                 ))
               
             )
             
    ),
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  thematic::thematic_shiny(font ='auto')
  
  # function to filter by continent and date
  filter_continent_date <- reactive({
    df <- cv_raw %>%
      filter(date == input$date_select) %>% 
      filter(!is.na(continent)) %>% 
      filter(continent %in% input$continent) %>%   
      select(continent, location, date, input$x_metric, input$y_metric, input$size_metric) %>%
      set_names(c("continent","location", "date", "x_metric","y_metric", "size_metric")) %>% 
      drop_na()
  })
  
  output$cvPlot <- renderPlotly({
    
    cv_filtered <- cv_raw %>% filter(location == input$country)
    
    cv_filtered <- cv_filtered %>% 
      mutate_if(is.numeric, list(percent_yoy =  ~ f_yoy(.))) %>% 
      mutate_at(vars(contains('percent_yoy')), ~ f_inf_to_na(.))
    
    find_vax_start_date <- reactive( {
      cv_filtered_vacc_start <-  cv_filtered %>%
        select(date, people_vaccinated_per_hundred) %>% 
        filter(people_vaccinated_per_hundred>0) 
      
      date_start <-  cv_filtered_vacc_start[1,1] 
      
    })
    
    
    vax_start_date <- find_vax_start_date()
    
    
    
    cv_filtered[is.na(cv_filtered$people_fully_vaccinated_per_hundred) & 
                  cv_filtered$location==input$country, "people_fully_vaccinated_per_hundred"] <- 0
    
    cv_filtered[is.na(cv_filtered$people_vaccinated_per_hundred) & 
                  cv_filtered$location==input$country, "people_vaccinated_per_hundred"] <- 0
    
    cv_filtered[is.na(cv_filtered$total_boosters_per_hundred) & 
                  cv_filtered$location==input$country, "total_boosters_per_hundred"] <- 0
    
    #cv_filtered <- head(cv_filtered,-2)
    
    
    if (input$free_y_axis == F & input$y == "new_deaths_per_million"){
      y_max <- 15
      y_min <- 0
    }
    else if (input$free_y_axis == F  & input$y == "new_cases_per_million"){
      y_max <- 1000
      y_min <- 0
    }else if (input$y == "new_deaths_smoothed_per_million_percent_yoy" | input$y == "new_cases_smoothed_per_million_percent_yoy") {
      cv_filtered <- cv_filtered %>% filter(date > "2021-04-01")
      y_max <- cv_filtered %>% select(input$y) %>% max(na.rm = TRUE)
      y_min <- -100
    }
    else {
      y_max <- cv_filtered %>% select(input$y) %>% max(na.rm = TRUE)
      y_min <- 0
    }
    
    colour_label <- names(time_series_colour_list)[which(unlist(time_series_colour_list, use.names = F) == input$colour)]
    
    cv_filtered_2 <- cv_filtered %>% select(input$y)
    print(cv_filtered_2)
    
    if (all(is.na(cv_filtered_2))) {
      head = paste0(input$country, " - No data available")
    }else{
      head = paste0(input$country)
    }
    
    ggplotly(
      ggplot(cv_filtered, aes_string(x = 'date', y = input$y, colour = input$colour)) +
        geom_point(size=1) +
        geom_smooth(fill=NA, size=0.5, colour='#FF8C00',span = input$smoothing,se=F) +
        {if(input$vaccine_start_check & !all(is.na(cv_filtered_2)))geom_vline(xintercept=as.numeric(vax_start_date),
                                                                              linetype=3, colour="red", alpha = 0.7)} +
        {if(all(is.na(cv_filtered_2)))annotate("text", x = Sys.Date() -90, y = 7.5, label = "No data available")} +
        scale_x_date(breaks = date_breaks("3 month"),
                     labels = date_format("%b-%Y"),
                     limits = as.Date(c("2020-02-01", Sys.Date() + 30))) +
        ylab(names(time_series_list)[which(unlist(time_series_list, use.names = F) == input$y)]) +
        labs(x = 'Date', title = head, color=colour_label) +
        ylim(y_min,y_max) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1),
              axis.title = element_text(size = 13, family="serif"),
              axis.text = element_text(size = 10, family="serif"),
              legend.title = element_text(family="serif"),
              plot.title = element_text(size = 16, family="serif")),
      
      dynamicTicks = 'x',originalData = F, tooltip = c("x", "y", "colour")) %>%
      layout(hovermode = 'closest') %>% 
      style(hoverinfo = 'none', traces = 2) 
    
  })
  
  output$scatterPlot <- renderPlotly({
    cv_filtered <- cv_raw %>% filter(location == input$country_scatter)
    
    head = paste0(input$country_scatter, " - Relation between ", input$y_axis, " and ", input$x_axis)
    
    cv_filtered[is.na(cv_filtered$people_fully_vaccinated_per_hundred) & 
                  cv_filtered$location==input$country_scatter, "people_fully_vaccinated_per_hundred"] <- 0
    
    cv_filtered[is.na(cv_filtered$people_vaccinated_per_hundred) & 
                  cv_filtered$location==input$country_scatter, "people_vaccinated_per_hundred"] <- 0
    
    cv_filtered[is.na(cv_filtered$total_boosters_per_hundred) & 
                  cv_filtered$location==input$country_scatter, "total_boosters_per_hundred"] <- 0
    
    cv_filtered <- head(cv_filtered,-2)
    
    cv_filtered <- cv_filtered %>% filter(people_fully_vaccinated_per_hundred > 1)
    
    ggplotly(
      ggplot(cv_filtered, aes_string(y = input$y_axis, x = input$x_axis, colour = 'people_fully_vaccinated_per_hundred')) +
        geom_point() +
        {if(input$linear)geom_smooth(size = 0.5, colour = 'orange',span = input$smoothing_scatter, se=F, method = lm)} +
        {if(!input$linear)geom_smooth(size = 0.5, colour = 'orange',span = input$smoothing_scatter, se=F)} +
        labs(title = head, x = input$x_axis, color = 'People fully vaccinated (%)') +
        theme(axis.title = element_text(size = 13, family="serif"),
              legend.title = element_text(family="serif"),
              axis.text = element_text(size = 10, family="serif")),
      
      dynamicTicks = 'x',originalData = F, tooltip = c("x", "y")) %>%
      layout(hovermode = 'closest') %>% 
      style(hoverinfo = 'none', traces = 2)
    
  })
  
  
  output$country_table <- renderDataTable({
    
    cv_raw %>% filter(location == input$country_data) %>% 
      select(-c(continent,new_cases_smoothed,new_deaths_smoothed,new_cases_smoothed_per_million,
                new_deaths_smoothed_per_million,new_tests_smoothed,new_tests_smoothed_per_thousand,new_vaccinations_smoothed,
                new_vaccinations_smoothed_per_million,
                population,
                population_density,
                median_age,
                aged_65_older,
                aged_70_older,
                gdp_per_capita,
                extreme_poverty,
                cardiovasc_death_rate,
                diabetes_prevalence,
                female_smokers,
                male_smokers,
                handwashing_facilities,
                hospital_beds_per_thousand,
                life_expectancy,
                human_development_index
      )) %>% arrange(desc(date))
    
  })
  
  output$country_dem <- renderDataTable({
    
    cv_raw %>% filter(location == input$country_data) %>% 
      select(c(location, population, population_density, median_age,
               aged_65_older,
               aged_70_older,
               gdp_per_capita,
               extreme_poverty,
               cardiovasc_death_rate,
               diabetes_prevalence,
               female_smokers,
               male_smokers,
               handwashing_facilities,
               hospital_beds_per_thousand,
               life_expectancy,
               human_development_index
      )) %>% tail(1)
    
  },options = list(paging = FALSE,searching = FALSE))
  
  
  filter_country_measure <- reactive({
    df <- cv_raw %>%
      select(!continent) %>% 
      filter(location %in% input$country_compare & date >= input$date_range_country[1] & date <= input$date_range_country[2]) %>% 
      select(location, date, input$metric_compare) %>%
      set_names(c("location", "date", "metric")) %>% 
      arrange(date)
  })
  
  filter_country_measure_f <- function(df){
    df <- df %>%
      select(!continent) %>% 
      filter(location %in% input$country_compare & date >= input$date_range_country[1] & date <= input$date_range_country[2]) %>% 
      select(location, date, input$metric_compare) %>%
      set_names(c("location", "date", "metric")) %>% 
      arrange(date)
    return (df)
  }
  
  output$country_compare <- renderPlot({
    ggplot(filter_country_measure(), aes(y = metric, x = date, color = location)) +
      geom_line(size = 1.5) +
      labs(color = "Country Name") +
      ylab(names(metric_smoothed_list)[which(unlist(metric_smoothed_list, use.names = F) == input$metric_compare)]) +
      xlab("Date") +
      scale_y_continuous(label = comma) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            axis.title = element_text(size = 14, family="serif"),
            axis.text = element_text(size = 12, family="serif"),
            legend.title = element_text(size = 14,family="serif"),
            plot.title = element_text(size = 16, family="serif")) +
      scale_x_date(breaks = date_breaks("3 month"),labels = date_format("%b-%Y")) +
      ggtitle(names(metric_smoothed_list)[which(unlist(metric_smoothed_list, use.names = F) == input$metric_compare)])
  })
  
  
  output$country_scatter <- renderPlot({
    
    ggplot(filter_continent_date(), aes(x = x_metric, y = y_metric, label = location)) +
      geom_point(data = filter_continent_date(), aes(color = continent,size = size_metric)) +
      #geom_smooth(method = lm, se = F, colour = 'orange') +
      {if(input$linear_country)geom_smooth(size = 1, colour = 'black',span = input$smoothing_country, se=F, method = lm)} +
      {if(!input$linear_country)geom_smooth(size = 1, colour = 'black',span = input$smoothing_country, se=F)} +
      scale_size_continuous(range = c(2,10)) +
      geom_text_repel(max.overlaps = 30, size = 3) +
      {if(input$linear_country)annotate("text", label=paste0("R = ", round(with(filter_continent_date(), cor.test(x_metric, y_metric,method = "pearson"))$estimate, 2),
                                                             ", p = ", round(with(filter_continent_date(), cor.test(x_metric, y_metric,method = "pearson"))$p.value, 3),
                                                             ", n = ", nrow(filter_continent_date())),
                                        x = max(filter_continent_date() %>% select(x_metric)) - max(filter_continent_date() %>% select(x_metric) * 0.20), y = max(filter_continent_date() %>% select(y_metric)) + 10, color="black", size=5)} +
      ylab(names(cv_raw_list)[which(unlist(cv_raw_list, use.names = F) == input$y_metric)]) +
      xlab(names(cv_raw_list)[which(unlist(cv_raw_list, use.names = F) == input$x_metric)]) +
      labs(color = "Continent", size = names(cv_raw_list)[which(unlist(cv_raw_list, use.names = F) == input$size_metric)]) +
      ggtitle(paste0(names(cv_raw_list)[which(unlist(cv_raw_list, use.names = F) == input$y_metric)], " vs ",
                     names(cv_raw_list)[which(unlist(cv_raw_list, use.names = F) == input$x_metric)], ' as of ', input$date_select)) +
      guides(color = guide_legend(override.aes = list(size = 7))) +
      theme(axis.title = element_text(size = 14, family="serif"),
            axis.text = element_text(size = 12, family="serif"),
            legend.title = element_text(size = 14,family="serif"),
            plot.title = element_text(size = 14, family="serif")) 
    
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)
