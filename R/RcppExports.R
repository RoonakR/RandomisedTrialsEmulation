# Generated by using Rcpp::compileAttributes() -> do not edit by hand
# Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#' Expand Function
#'
#' @param d A dataframe with for_period, period_new and switch_new columns
#' @param range The range of the period values
#' @param first_period First period value to start expanding about
NULL

#' Censoring Function
#'
#' @param sw_data A dataframe with the columns needed in censoring process
NULL

expand_func <- function(d, range, first_period) {
    .Call('_RandomisedTrialsEmulation_expand_func', PACKAGE = 'RandomisedTrialsEmulation', d, range, first_period)
}

censor_func <- function(sw_data) {
    .Call('_RandomisedTrialsEmulation_censor_func', PACKAGE = 'RandomisedTrialsEmulation', sw_data)
}

