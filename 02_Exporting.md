Covid Data and Restrictions - Exporting to CSV
================

Load required packages

``` r
if (!require(pacman)) install.packages('pacman')
library(pacman)
p_load(tidyverse)
options(scipen=999)
options(warn=-1)
```

Import data frames saved from Extraction.RMD

``` r
df_large <- readRDS("OxOw_Extraction_large.rds")
df_small <- readRDS("OxOw_Extraction_small.rds")
df_europe_20201230_small <- readRDS("OxOw_Extraction_europe_20201230_small.rds")
df_europe_20211230_small <- readRDS("OxOw_Extraction_europe_20211230_small.rds")
df_europe_20220520_small <- readRDS("OxOw_Extraction_europe_20220520_small.rds")
```

Export both large and small data sets as .csv files

``` r
write_excel_csv(df_large, "OxCGR_Owid_data_large.csv")
write_excel_csv(df_small, "OxCGR_Owid_data_small.csv")
write_excel_csv(df_europe_20201230_small, "OxOw_Extraction_europe_20201230_small.csv")
write_excel_csv(df_europe_20211230_small, "OxOw_Extraction_europe_20211230_small.csv")
write_excel_csv(df_europe_20220520_small, "OxOw_Extraction_europe_20220520_small.csv")
```
