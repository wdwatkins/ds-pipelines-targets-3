summarize_targets <- function(ind_file, targets_vector) {
  ind_tbl <- tar_meta(all_of(targets_vector)) %>%
    select(tar_name = name, filepath = path, hash = data) %>%
    mutate(filepath = unlist(filepath))

  readr::write_csv(ind_tbl, ind_file)
  return(ind_file)
}
