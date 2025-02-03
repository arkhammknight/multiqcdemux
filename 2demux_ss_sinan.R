library(tidyverse)
library(hrbrthemes)
library(paletteer)
library(ggtext)
library(scales)
library(gt)
library(googlesheets4)
library(highcharter)
library(janitor)
library(xml2)
library(gtExtras)

setwd("/usr/src/app/Reports") # SET THE REPORT DIR

# Import Dataset and Index ------------------------------------------------
read_samplesheet <- function(file, section = c("header", "reads", "settings", "data")) {
  
  row_header   <- str_which(readLines(file), pattern = "\\[Header\\]")
  row_reads    <- str_which(readLines(file), pattern = "\\[Reads\\]")
  row_settings <- str_which(readLines(file), pattern = "\\[Settings\\]")
  row_data     <- str_which(readLines(file), pattern = "\\[Data\\]")
  row_final    <- length(readLines(file))
  
  output <- list(
    header = readLines(file)[(2):(row_reads-1)] %>% I() %>%
      read_csv(col_names = c("parameter", "value")) %>%
      select(parameter, value) %>%
      filter(!is.na(parameter)),
    
    reads = readLines(file)[(row_reads+1):(row_settings-1)] %>%
      str_remove_all(",*$") %>%
      keep(~.x != ""),
    
    settings = readLines(file)[(row_settings+1):(row_data-1)]  %>% I() %>%
      read_csv(col_names = c("parameter", "value")) %>%
      select(parameter, value) %>%
      filter(!is.na(parameter)),
    
    data = readLines(file)[(row_data+1):row_final] %>% I() %>%
      read_csv()
  )
  
  return(output[[section]])
}

demux_read <- function(demux_stats = "/usr/src/app/Reports/Demultiplex_Stats.csv", 
                       sample_sheet = "/usr/src/app/Reports/SampleSheet.csv") {
  
  ss <- read_samplesheet(sample_sheet, section = "data") %>% 
    janitor::clean_names()
  
  read_csv(demux_stats) %>% 
    janitor::clean_names() %>% 
    filter(sample_id != "Undetermined") %>% 
    separate(index, into = c("index", "index2"), sep = "-") %>% 
    left_join(ss) %>% 
    mutate(lane = as.character(lane))
}

demux <- demux_read()

run_id <- read_xml("RunInfo.xml") %>% 
  xml_find_first(".//Run") %>% 
  xml_attr("Id")

demux %>% 
  mutate(lane = paste0("Lane ", lane)) %>%
  mutate(lane = fct_rev(lane)) %>%
  summarise(
    samples = n(),
    mean_reads = mean(number_reads),
    min_reads = min(number_reads),
    max_reads = max(number_reads), 
    total_reads = sum(number_reads),
    .by = c(sample_project, lane)) %>%  
  arrange(desc(lane)) %>% 
  gt(groupname_col = "lane") %>% 
  fmt_number(c(mean_reads, total_reads, min_reads, max_reads), 
             suffixing = T, decimals = 1) %>% 
  fmt_missing(
    columns = everything(),
    rows = everything(),
    missing_text = "---"
  ) %>% 
  cols_merge_range(
    col_begin = min_reads,
    col_end = max_reads, sep = " - "
  ) %>% 
  tab_spanner(
    label = "Reads per Sample",
    columns = c(mean_reads, min_reads)
  ) %>% 
  tab_spanner(
    label = "Samples",
    columns = c(samples)
  ) %>% 
  tab_spanner(
    label = "Library",
    columns = c(total_reads)
  ) %>% 
  cols_label(
    lane = md("**Lane**"),
    sample_project = md("**Pool**"),
    samples = md("**Total**"),
    total_reads = md("**Yield**"),
    mean_reads = md("**Mean**"),
    min_reads = md("**Min - Max**"),
  ) %>% 
  cols_width(
    sample_project ~ px(270),
    total_reads ~ px(110),
    mean_reads ~ px(90),
    min_reads ~ px(150),
  ) %>%
  tab_style(
    style = list(
      cell_text(weight = "bold"),
      cell_fill(color = "#edf4f7")
    ),
    locations = cells_row_groups()
  ) %>% 
  tab_style(
    style = list(
      cell_text(weight = "bold"),
      cell_fill(color = "#def1fc")
    ),
    locations = cells_title()
  ) %>% 
  tab_header(subtitle = run_id, title = "Demultiplexing Summary") %>% 
  opt_align_table_header(align = "left") %>% 
  gtsave(paste0("/usr/src/app/Reports/", run_id, ".html"))

  
