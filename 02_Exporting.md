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
df <- readRDS("OxOw_Extraction_large.rds")
df_small <- readRDS("OxOw_Extraction_small.rds")
```

Export both large and small data sets as .csv files

``` r
write_excel_csv(df, "OxCGR_Owid_data_large.csv")
write_excel_csv(df_small, "OxCGR_Owid_data_small.csv")
```
