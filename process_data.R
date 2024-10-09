# process the input dataset

# required packages and functions ---------------------------------------------
library("optparse")
library("dplyr")
library("readr")
library("stringr")
library("here")
library("haven")

here::i_am("README.md")

source(here::here("utils.R"))
# set up command-line args ----------------------------------------------------
parser <- OptionParser()
parser <- add_option(parser, "--data-dir",
                     default = "G:/CTRHS/Sentinel/Innovation_Center/NLP_COVID19_Carrell/PROGRAMMING/SAS Datasets/Replicate VUMC Analysis/Sampling for Chart Review/Severity-specific silver-standard surrogates/",
                     help = "The input data directory")
parser <- add_option(parser, "--analysis-data-dir",
                     default = "G:/CTRHS/Sentinel/Innovation_Center/NLP_COVID19_Carrell/PheNorm/analysis_datasets_negation_0_normalization_0_dimension-reduction_0_train-on-gold_0/",
                     help = "The analysis data directory")
parser <- add_option(parser, "--data-name",
                     default = "phase_1_updated_symptomatic_covid_kpwa_preprocessed_data.rds",
                     help = "The name of the dataset")
parser <- add_option(parser, "--analysis",
                     default = "phase_1_updated_symptomatic_covid",
                     help = "The name of the analysis")
parser <- add_option(parser, "--cui", default = "C5203670",
                     help = "The CUI of interest (for the outcome of interest)")
parser <- add_option(parser, "--study-id", default = "Studyid",
                     help = "The study id variable")
parser <- add_option(parser, "--utilization", default = "Utiliz",
                     help = "The utilization variable")
parser <- add_option(parser, "--weight", default = "Sampling_Weight",
                     help = "Inverse probability of selection into gold-standard set")
args <- parse_args(parser, convert_hyphens_to_underscores = TRUE)

if (!dir.exists(args$analysis_data_dir)) {
  dir.create(args$analysis_data_dir, recursive = TRUE)
  txt_for_readme <- "# Analysis datasets\n\nThis folder contains analysis-ready datasets, resulting from processing raw data into PheNorm-ready form."
  writeLines(txt_for_readme, con = file.path(args$analysis_data_dir, "README.md"))
}

# process the dataset ---------------------------------------------------------
# read in the data
if (endsWith(args$data_name, ".rds")) {
  input_data <- readRDS(file.path(args$data_dir, args$data_name))
} else if (endsWith(args$data_name, ".sas7bdat")) {
  input_data <- read_sas(file.path(args$data_dir, args$data_name))
} else {
  input_data <- readr::read_csv(file.path(args$data_dir, args$data_name), na = c("NA", ".", ""))
}
# get to the correct set of CUI variables:
#   if we're using all mentions, drop non-negated mentions (if they exist)
#   drop normalized (or nonnormalized) if requested
# only_cuis_of_interest <- filter_cui_variables(dataset = input_data, use_nonnegated = args$use_nonneg,
#                                               use_normalized = args$use_normalized,
#                                               use_nonnormalized = args$use_nonnormalized,
#                                               nonneg_id = args$nonneg_label)

if ('FILTER_GROUP' %in% names(input_data)) {
  input_data['FILTER_GROUP'] <- NULL
}
data_names <- names(input_data)
cui_names <- data_names[grepl("C[0-9]", data_names, ignore.case = TRUE)]
# note that "silver" is required to be in the variable name for all silver labels
silver_labels <- data_names[grepl("silver", data_names, ignore.case = TRUE)]
nlp_names <- c(silver_labels, args$utilization, cui_names)
# structured data: *not* silver labels, utilization, CUIs, or weights!
structured_data_names <- data_names[!(data_names %in% c(args$study_id,
                                                        nlp_names, args$weight))]

# if requested to train on gold-labeled data (as well as non-gold-labeled data),
# change training/testing split
processed_data <- process_data(dataset = input_data,
                               structured_data_names = structured_data_names,
                               nlp_data_names = nlp_names,
                               study_id = args$study_id,
                               utilization_variable = args$utilization,
                               weight = args$weight)
# drop variables in the training data with 0 variance/only one unique value, outside of the special columns
all_data <- processed_data$all


# combine and log-transform ---------------------------------------------------


# log transform
log_all <- apply_log_transformation(
  dataset = all_data,
  varnames = names(all_data)[!(
    names(all_data) %in% c(args$study_id, args$weight, "FILTER_GROUP")
  )],
  utilization_var = args$utilization
)

analysis_data <- list(
  "all" = log_all,
  "utilization_variable" = args$utilization, "silver_labels" = silver_labels
)
# save analysis dataset and some data summary statistics -----------------------
saveRDS(
  analysis_data,
  file = file.path(
    args$analysis_data_dir,
    paste0(args$analysis, "_analysis_data.rds")
  )
)
summary_stats <- tibble::tibble(
  `Summary Statistic` = c("Sample size (total)",
                          "Number of NLP features"),
  `Value` = c(nrow(input_data),
              length(cui_names)) # need to account for study id, utilization
)
readr::write_csv(
  summary_stats, file = file.path(args$analysis_data_dir, paste0(args$analysis, "_summary_statistics.csv"))
)
print("Data processing complete.")