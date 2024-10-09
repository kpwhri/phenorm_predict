#!/usr/local/bin/Rscript

# Obtain predicted probabilities on the entire dataset (training and testing)

# required packages and functions ---------------------------------------------
library("optparse")
library("dplyr")
library("tidyr")
library("readr")
library("stringr")
library("PheNorm")
library("ggplot2")
library("cowplot")
theme_set(theme_cowplot())
library("here")

here::i_am("README.md")

source(here::here("utils.R"))
# set up command-line args ----------------------------------------------------
parser <- OptionParser()
parser <- add_option(parser, "--data-dir",
                     help = "The input data directory (output from `process_data.R`)")
parser <- add_option(parser, "--output-dir",
                     help = "The output directory")
parser <- add_option(parser, "--model",
                     help = "Path to model: should end in `_phenorm_output.rds`.")
parser <- add_option(parser, "--analysis",
                     default = "phase_1_updated_symptomatic_covid", help = "The name of the analysis")
parser <- add_option(parser, "--weight", default = "Sampling_Weight",
                     help = "Inverse probability of selection into gold-standard set")
parser <- add_option(parser, "--study-id", default = "Studyid", help = "The study id variable")
args <- parse_args(parser, convert_hyphens_to_underscores = TRUE)

# load in data and fitted PheNorm object ---------------------------------------
output_dir <- args$output_dir
analysis_data <- readRDS(
  file = file.path(
    args$data_dir,
    paste0(args$analysis, "_analysis_data.rds")
  )
)
silver_labels <- analysis_data$silver_labels
all_data <- analysis_data$all
id_var <- which(grepl(args$study_id, names(all_data), ignore.case = TRUE))
print(id_var)
all_minus_id <- all_data[, -id_var]
print(all_minus_id %>% head(5))
all_ids <- all_data[id_var]
phenorm_analysis <- readRDS(file = args$model)
fit <- phenorm_analysis$fit

# make predictions on entire dataset -------------------------------------------
# get features used to train PheNorm model
model_fit_names <- gsub("SX.norm.corrupt", "", rownames(fit$betas))
model_features <- model_fit_names[!(model_fit_names %in% c(silver_labels, args$weight))]

# get predictions
set.seed(1234)
preds_all <- predict.PheNorm(
  phenorm_model = fit, newdata = all_minus_id, silver_labels = silver_labels,
  features = model_features,
  utilization = analysis_data$utilization_variable, aggregate_labels = silver_labels
)
names(preds_all) <- paste0("pred_prob_", names(preds_all))
preds_all_df <- data.frame(all_ids, preds_all)
names(preds_all_df)[1] <- args$study_id

# set up whole vector of predictions
# unordered_preds <- rbind(preds_test_df, preds_train_df)
# ids_only <- data.frame(all_data[[id_var]])
# names(ids_only) <- args$study_id
# pred_dataset <- ids_only %>%
#   left_join(unordered_preds, by = args$study_id)
# save
readr::write_csv(
  preds_all_df, file = file.path(
    output_dir,
    paste0(args$analysis, "_phenorm_all_predicted_probabilities_using_model.csv")
  )
)
# create a histogram of predicted probabilities for each silver label
# first, get the base-R hist breakpoints
long_pred_dataset <- preds_all_df %>%
  pivot_longer(cols = starts_with("pred"), names_to = "model", values_to = "pred_prob") %>%
  mutate(model = gsub("pred_prob_", "", model))
breaks <- pretty(range(long_pred_dataset$pred_prob), n = nclass.Sturges(long_pred_dataset$pred_prob),
                 min.n = 1)
pred_prob_hist <- long_pred_dataset %>%
  ggplot(aes(x = pred_prob)) +
  geom_histogram(breaks = breaks) +
  labs(x = "Predicted probability", y = "Count") +
  facet_wrap(vars(model))
ggsave(filename = file.path(
  output_dir, paste0(args$analysis, "_phenorm_predicted_probabilities_hist_using_model.png")
), pred_prob_hist, width = 11, height = 8, units = "in", dpi = 300)
print("Predicted probabilities obtained on entire dataset.")