
library(targets)
library(tarchetypes)
library(tibble)
suppressPackageStartupMessages(library(dplyr))

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr", "rnaturalearth", "cowplot",
                            "lubridate", "leaflet", "leafpop", "htmlwidgets"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source('1_fetch/src/get_site_data.R')
source('2_process/src/tally_site_obs.R')
source('2_process/src/summarize_targets.R')
source("3_visualize/src/map_sites.R")
source('3_visualize/src/plot_site_data.R')
source('3_visualize/src/plot_data_coverage.R')
source('3_visualize/src/map_timeseries.R')

# Configuration
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Targets

mapped_by_state_targets <- tar_map(
  values = tibble(state_abb = states) %>%
    mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
  tar_target(nwis_inventory, filter(oldest_active_sites, state_cd == state_abb)),
  tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
  tar_target(tally, tally_site_obs(nwis_data)),
  tar_target(timeseries_png,
             plot_site_data(state_plot_files, nwis_data, parameter),
             format = 'file'),
  names = state_abb,
  unlist = FALSE
)


list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),
  # tar_map(
  #   values = tibble(states = states),
  #   tar_target(find_oldest_sites(states, parameter)
  #   )
  # ),
  # Map oldest sites
  mapped_by_state_targets,
  tar_combine(
    name = obs_tallies,
    mapped_by_state_targets$tally,
    command = bind_rows(!!!.x)
  ),
  tar_combine(
    summary_state_timeseries_csv,
    mapped_by_state_targets$timeseries_png,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
    format="file"
  ),
  tar_target(
    data_coverage_png,
    plot_data_coverage(oldest_site_tallies = obs_tallies,
                       out_file = '3_visualize/out/data_coverage.png',
                       parameter),
    format = 'file'
  ),
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  ),
  tar_target(
    timeseries_map_html,
    map_timeseries(site_info = oldest_active_sites,
                   plot_info_csv = summary_state_timeseries_csv,
                   out_file = '3_visualize/out/timeseries_map.html'),
    format = 'file'
  )
)
