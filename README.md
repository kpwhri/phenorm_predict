# PheNorm Predict

An R implementation of PheNorm for using an existing model.

## Overview

The following is an R implementation of PheNorm. This repository has been set up to facilitate applying the PheNorm algorithm (rather than building).

For developing a new model using PheNorm, consider instead following the steps in the [Sentinel Scalable NLP github](https://github.com/kpwhri/Sentinel-Scalable-NLP).

## Prerequisites

1. Create a cohort (e.g., using [SAS code](https://github.com/kpwhri/Sentinel-Scalable-NLP/tree/master/High-Sensitivity-Filter/Programs))
2. Process the corpus output by `04_CLinical_Text_for_NLP.sas` with mml_utils using [configuration files](https://github.com/kpwhri/Sentinel-Scalable-NLP/tree/master/Prediction-Modeling/Anaphylaxis/NLP/configs)
   * A step-by-step guide is provided in the [`mml_utils` documentation](https://github.com/kpwhri/mml_utils/tree/master/examples/phenorm)
3. Run PheNorm using this code
   * You will need a selected model and a cutoff.

## Applying PheNorm Algorithm

### Install Required Packages: `install_packages.R`

Run the `install_packages.R` script to ensure that your R environment has the necessary prerequisites installed to run PheNorm.

    Rscript install_packages.R

### Prepare Dataset: `process_data.R`

Run the `process_data.R` script to prepare and format the dataset. You will need to supply several command line options.

* `--data-dir DATA_DIR`
  * The path to the folder containing the combined NLP and structured data output by the SAS processes.
  * By default, the folder is called `05_Silver_Labels_and_Analytic_File`.
* `--analysis-data-dir ANALYSIS_DATA_DIR`
  * The output folder for this analysis.
  * Perhaps use the name `06_R_PrepDatasets`
* `--data-name SAS_DATASET`
  * This is the SAS dataset present in `DATA_DIR`.
  * The default name is `fe_nlp_modeling_file.sas7bdat`
* `--analysis OUT_DATASET` 
  * The name of the output file to be placed in `ANALYSIS_DATA_DIR`
* `--cui CUI`
  * The CUI of interest for the outcome of interest.
  * For Anaphylaxis, use `C0002792`
* `--study-id STUDYID`
  * The name of the field/variable/column containing the studyid
  * By default, this is `Obs_ID`

Example command line (on Windows):
```commandline
C:\R\bin\x64\R.exe ** -f C:/code/phenorm_predict/process_data.R
    --data-dir C:/data/05_Silver_Labels_and_Analytic_File
    --analysis-data-dir C:/data/06_R_PrepDatasets
    --data-name fe_nlp_modeling_file.sas7bdat
    --analysis cui_nlp_vars
    --cui C0002792
    --study-id Obs_ID
```

### Get Predicted Probabilities: `get_predicted_probabilities.R`

Run the `get_predicted_probabilities.R` script on the dataset output by `process_data.R` to generate a set of predicted probabilities.

* `--data-dir DATA_DIR`
  * Path to output directory when running `process_data.R`
  * Suggested folder name was `06_R_PrepDatasets`
* `--model MODEL_PATH`
  * Path to RDS model for generating predicted probabilities
* `--analysis cui_nlp_vars`
  * Name of output dataset from `process_data.R`
  * Suggested name was `cui_nlp_vars`
* `--output-dir OUTPUT_DIR`
  * Path to output directory
  * Considering giving the name `07_R_PredProbs`
* `--study-id STUDYID`
    * The name of the field/variable/column containing the studyid
    * By default, this is `Obs_ID`

Example command line (on Windows):
```commandline
C:\R\bin\x64\R.exe ** -f C:/code/phenorm_predict/get_predicted_probabilities.R
    --data-dir C:/data/06_R_PrepDatasets 
    --model C:/data/07_R_PredProbs/models/anaphylaxis_model.rds 
    --analysis cui_nlp_vars 
    --output-dir C:/data/07_R_PredProbs 
    --study-id Obs_ID
```

### Interpretation

The `get_predicted_probabilities.R` script will output two files:
* `{analysis}_phenorm_all_predicted_probabilities_using_model.csv`
  * Predicted probabilities for the four models, as well as an aggregate model with the average of the other four.
  * Here, probabilities closer to 1.0 indicate increased predicted likelihood of having the condition (e.g., anaphylaxis) 
    * `pred_prob_SILVER_ANA_DX_N_ENCS`
    * `pred_prob_SILVER_ANA_MENTIONS_N`
    * `pred_prob_SILVER_ANA_CUI_NOTES_N`
    * `pred_prob_SILVER_ANA_EPI_MENTIONS_N`
    * `pred_prob_Aggregate`
* `{analysis}_phenorm_predicted_probabilities_hist_using_model.png`
  * Histograms of the 5 models by predicted probability

The target model (e.g., `pred_prob_Aggregate`) and cutoff (e.g., 0.74) should have been provided. If you do not yet have a model/cutoff, you will need to compare the probabilities against a gold standard and select the ideal model/cutoff combination.

With the example model and cutoff of `pred_prob_Aggregate` and 0.74, respectively:
* Load the output CSV file
* Select the variable/field/column indicated by the selected model
* Assign all studyids with $\geq 0.74$ the classification of 'anaphylaxis' (or whatever target condition).


## Acknowledgements

* Original R code written by [Brian Williamson](https://github.com/bdwilliamson)
