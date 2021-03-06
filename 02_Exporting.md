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
df_europe_20201230_large <- readRDS("OxOw_Extraction_europe_20201230_large.rds")
df_europe_20211230_large <- readRDS("OxOw_Extraction_europe_20211230_large.rds")
df_europe_20220520_large <- readRDS("OxOw_Extraction_europe_20220520_large.rds")
df_world_20211230_large <- readRDS("OxOw_Extraction_world_20211230_small.rds")
```

Export both large and small data sets as .csv files

``` r
write_excel_csv(df_large, "OxCGR_Owid_data_large.csv")
write_excel_csv(df_small, "OxCGR_Owid_data_small.csv")
write_excel_csv(df_europe_20201230_large, "OxOw_Extraction_europe_20201230_large.csv")
write_excel_csv(df_europe_20211230_large, "OxOw_Extraction_europe_20211230_large.csv")
write_excel_csv(df_europe_20220520_large, "OxOw_Extraction_europe_20220520_large.csv")
write_excel_csv(df_world_20211230_large, "OxOw_Extraction_world_20211230_large.csv")
```
