#' Read Data Function
#'
#' This function read data from csv file and select the columns you need
#' @param data_address Address for data read with bigmemory
#' @param data_path Path of the csv file
#' @param id_num Id number
#' @param id Name of the data column for id feature Defaults to id
#' @param period Name of the data column for period feature Defaults to period
#' @param treatment Name of the data column for treatment feature Defaults to treatment
#' @param outcome Name of the data column for outcome feature Defaults to outcome
#' @param eligible Indicator of whether or not an observation is eligible to be expanded about Defaults to eligible
#' @param eligible_wts_0 Eligibility criteria used in weights for model condition Am1 = 0
#' @param eligible_wts_1 Eligibility criteria used in weights for model condition Am1 = 1
#' @param outcomeCov_var List of individual baseline variables used in final model
#' @param cov_switchn Covariates to be used in logistic model for switching probabilities for numerator model
#' @param cov_switchd Covariates to be used in logistic model for switching probabilities for denominator model
#' @param cov_censed Covariates to be used in logistic model for censoring weights for denominator model
#' @param cov_censen Covariates to be used in logistic model for censoring weights for nominator model
#' @param cense Censoring variable
#' @param where_var Variables used in where conditions used in subsetting the data used in final analysis (where_case), the variables not included in the final model
#' read_data()

read_data <- function(data_address, data_path=NA, id_num=NA,
                      id="id",
                      period="period",
                      treatment="treatment",
                      outcome="outcome",
                      eligible="eligible",
                      eligible_wts_0=NA,
                      eligible_wts_1=NA,
                      outcomeCov_var=NA,
                      cov_switchn=NA, cov_switchd=NA,
                      cov_censed=NA, cov_censen=NA, cense=NA, where_var=NA){
  covs <- c()
  if(any(!is.na(eligible_wts_0))){
    covs <- c(covs, eligible_wts_0)
  }
  if(any(!is.na(eligible_wts_1))){
    covs <- c(covs, eligible_wts_1)
  }
  if(any(!is.na(outcomeCov_var))){
    covs <- c(covs, outcomeCov_var)
  }
  if(any(!is.na(cov_switchd))){
    covs <- c(covs, cov_switchd)
  }
  if(any(!is.na(cov_switchn))){
    covs <- c(covs, cov_switchn)
  }
  if(any(!is.na(cov_censed))){
    covs <- c(covs, cov_censed)
  }
  if(any(!is.na(cov_censen))){
    covs <- c(covs, cov_censen)
  }
  if(any(!is.na(cense))){
    covs <- c(covs, cense)
  }
  if(any(!is.na(where_var))){
    covs <- c(covs, where_var)
  }
  covs <- covs[!duplicated(covs)]
  cols = c(id, period, treatment, outcome, eligible, covs)
  if(!is.na(id_num)){
    data = data_address[mwhich(data_address, c("id"), c(id_num), c('eq')),]
  }else{
    data = fread(data_path, header = TRUE, sep = ",")
  }
  if(!eligible %in% colnames(data)){
    data$eligible = 1
  }
  data_new = as.data.table(data)
  data_new = subset(data_new, select=cols)
  tryCatch({
    suppressWarnings(setnames(data_new,
                              c(id, period, outcome, eligible, treatment),
                              c("id", "period", "outcome", "eligible", "treatment")))
  })
  if(any(!is.na(eligible_wts_0))){
    setnames(data_new, c(eligible_wts_0), c("eligible_wts_0"))
  }
  if(any(!is.na(eligible_wts_1))){
    setnames(data_new, c(eligible_wts_1), c("eligible_wts_1"))
  }
  rm(data, covs, cols)
  return(data_new)
}


#' Period Expanding Function
#'
#' This function get the data.table with period column and expand it based on it
#' @param y The data.table with period column

f <- function(y){
  last = !duplicated(y$period, fromLast=TRUE)
  last_ind = which(last == TRUE)
  return(seq(0, y$period[last_ind]))
}

#' For_period Feature Function
#'
#' This function get the data.table with period and id columns and generate the for_period feature
#' @param x The data.table with id and period columns
#' for_period_func()

for_period_func <- function(x){
  x_new = x[rep(1:.N, period+1), .(id, period)]
  x_new[, for_period := f(.BY), by=.(id, period)]
  return(x_new[, for_period])
}

#' Weight Calculation Function
#'
#' This function performs the calculation for weight of the data
#' @param sw_data A data.table
#' @param cov_switchn List of covariates to be used in logistic model for switching probabilities for numerator model
#' @param model_switchn List of models (functions) to use the covariates from cov_switchn
#' @param class_switchn Class variables used in logistic model for nominator model
#' @param cov_switchd List of covariates to be used in logistic model for switching probabilities for denominator model
#' @param model_switchd List of models (functions) to use the covariates from cov_switchd
#' @param class_switchd Class variables used in logistic model for denominator model
#' @param eligible_wts_0 Eligibility criteria used in weights for model condition Am1 = 0
#' @param eligible_wts_1 Eligibility criteria used in weights for model condition Am1 = 1
#' @param cense Censoring variable
#' @param pool_cense Pool the numerator and denominator models (0: split models by previous treatment Am1 = 0 and Am1 = 1 as in treatment models and 1: pool all observations together into a single numerator and denominator model) Defaults to 0
#' @param cov_censed List of covariates to be used in logistic model for censoring weights in denominator model
#' @param model_censed List of models (functions) to use the covariates from cov_censed
#' @param class_censed Class variables used in censoring logistic regression in denominator model
#' @param cov_censen List of covariates to be used in logistic model for censoring weights in numerator model
#' @param model_censen List of models (functions) to use the covariates from cov_censen
#' @param class_censen Class variables used in censoring logistic regression in numerator model
#' @param include_regime_length If defined as 1 a new variable (time_on_regime) is added to dataset - This variable stores the duration of time that the patient has been on the current treatment value
#' @param numCores Number of cores for parallel programming

weight_func <- function(sw_data, cov_switchn=NA, model_switchn=NA,
                        class_switchn=NA, cov_switchd=NA,
                        model_switchd=NA, class_switchd=NA,
                        eligible_wts_0=NA, eligible_wts_1=NA,
                        cense=NA, pool_cense=0, cov_censed=NA,
                        model_censed=NA, class_censed=NA,
                        cov_censen=NA, model_censen=NA, class_censen=NA,
                        include_regime_length=0,
                        numCores=NA){

  if(include_regime_length == 1){
    model_switchd <- c(model_switchd, "time_on_regime", "time_on_regime2")
    model_switchn <- c(model_switchn, "time_on_regime", "time_on_regime2")
  }
  # ------------------- eligible0 == 1 --------------------
  # --------------- denominator ------------------
  if(any(!is.na(cov_switchd))){
    len_d = length(model_switchd)
    regformd <- paste(
      paste("treatment", "~"),
      paste(
        paste(model_switchd, collapse="+"),
        sep="+"
      )
    )
  }else{
    len_d = 0
    regformd <- paste(
      paste("treatment", "~"),
      "1"
    )
  }

  if(any(!is.na(model_switchn))){
    len_n = length(model_switchn)
    regformn <- paste(
      paste("treatment", "~"),
      paste(
        paste(model_switchn, collapse="+"),
        sep="+"
      )
    )
  }else{
    len_n = 0
    regformn <- paste(
      paste("treatment", "~"),
      "1"
    )
  }

  d = list(
    list(sw_data[if(any(!is.na(eligible_wts_0)))
      (eligible0 == 1 & eligible_wts_0 == 1) else eligible0 == 1], regformd, class_switchd),
    list(sw_data[if(any(!is.na(eligible_wts_0)))
      (eligible0 == 1 & eligible_wts_0 == 1) else eligible0 == 1], regformn, class_switchn),
    list(sw_data[if(any(!is.na(eligible_wts_1)))
      (eligible1 == 1 & eligible_wts_1 == 1) else eligible1 == 1], regformd, class_switchd),
    list(sw_data[if(any(!is.na(eligible_wts_1)))
      (eligible1 == 1 & eligible_wts_1 == 1) else eligible1 == 1], regformn, class_switchn)
  )

  if(numCores == 1) {
    # cl <- makeCluster(numCores)
    # m = parLapply(cl, d, weight_lr)
    # stopCluster(cl)
    m = lapply(d, weight_lr)
  } else {
    m = mclapply(d, weight_lr, mc.cores=numCores)
  }

  print("P(treatment=1 | treatment=0) for denominator")
  model1 = m[[1]]
  print(summary(model1))
  switch_d0 = data.table(p0_d = model1$fitted.values,
                         eligible0 = unlist(model1$data$eligible0),
                         id = model1$data[, id],
                         period = model1$data[, period])

  # -------------- numerator --------------------
  print("P(treatment=1 | treatment=0) for numerator")

  model2 = m[[2]]
  print(summary(model2))
  switch_n0 = data.table(p0_n = model2$fitted.values,
                         eligible0 = unlist(model2$data$eligible0),
                         id = model2$data[, id],
                         period = model2$data[, period])
  # ------------------- eligible1 == 1 --------------------
  # --------------- denominator ------------------
  print("P(treatment=1 | treatment=1) for denominator")
  model3 = m[[3]]
  print(summary(model3))
  switch_d1 = data.table(p1_d = model3$fitted.values,
                         eligible1 = unlist(model3$data$eligible1),
                         id = model3$data[, id],
                         period = model3$data[, period])
  # -------------------- numerator ---------------------------
  print("P(treatment=1 | treatment=1) for numerator")
  model4 = m[[4]]
  print(summary(model4))
  switch_n1 = data.table(p1_n = model4$fitted.values,
                         eligible1 = unlist(model4$data$eligible1),
                         id = model4$data[, id],
                         period = model4$data[, period])

  switch_0 = switch_d0[switch_n0, on = .(id=id, period=period,
                                         eligible0=eligible0)]
  switch_1 = switch_d1[switch_n1, on = .(id=id, period=period,
                                         eligible1=eligible1)]

  new_data = Reduce(function(x,y) merge(x, y,
                                        by = c("id", "period"),
                                        all = TRUE),
                    list(sw_data, switch_1, switch_0))

  rm(switch_d0, switch_d1, switch_n0, switch_n1, switch_1, switch_0)

  new_data[, eligible0.y := NULL]
  new_data[, eligible1.y := NULL]
  setnames(new_data, c("eligible0.x", "eligible1.x"),
           c("eligible0", "eligible1"))

  if(!is.na(cense)){
    if(any(!is.na(model_censed))){
      regformd <- paste(
        paste("1", "-"),
        paste(eval(cense), "~"),
        paste(
          paste(model_censed, collapse="+"),
          sep="+"
        )
      )
    }else{
      regformd <- paste(
        paste("1", "-"),
        paste(eval(cense), "~"),
        "1"
      )
    }
    if(any(!is.na(model_censen))){
      regformn <- paste(
        paste("1", "-"),
        paste(eval(cense), "~"),
        paste(
          paste(model_censen, collapse="+"),
          sep="+"
        )
      )
    }else{
      regformn <- paste(
        paste("1", "-"),
        paste(eval(cense), "~"),
        "1"
      )
    }

    if(pool_cense == 1){
      # -------------------- denominator -------------------------
      print("Model for P(cense = 0 |  X ) for denominator")
      # ------------------------------------------------------------

      d = list(
        list(new_data, regformd, class_censed),
        list(new_data, regformn, class_censen)
      )

      if(numCores == 1) {
        # cl <- makeCluster(numCores)
        # m = parLapply(cl, d, weight_lr)
        # stopCluster(cl)
        m = lapply(d, weight_lr)
      } else {
        m = mclapply(d, weight_lr, mc.cores=numCores)
      }

      model1.cense = m[[1]]
      print(summary(model1.cense))
      cense_d0 = data.table( pC_d = model1.cense$fitted.values,
                             id = model1.cense$data[, id],
                             period = model1.cense$data[, period])

      # --------------------- numerator ---------------------------
      print("Model for P(cense = 0 |  X ) for numerator")
      # ---------------------------------------------------------
      model2.cense = m[[2]]
      print(summary(model2.cense))
      cense_n0 = data.table( pC_n = model2.cense$fitted.values,
                             id = model2.cense$data[, id],
                             period = model2.cense$data[, period])

      new_data = Reduce(function(x,y) merge(x, y,
                                            by = c("id", "period"),
                                            all.x = TRUE, all.y = TRUE),
                        list(new_data, cense_d0, cense_n0))
      rm(cense_d0, cense_n0)
    }else{
      # ---------------------- denominator -----------------------
      print("Model for P(cense = 0 |  X, Am1=0) for denominator")
      # ---------------------- eligible0 ---------------------------

      d = list(
        list(new_data[eligible0 == 1], regformd, class_censed),
        list(new_data[eligible0 == 1], regformn, class_censen),
        list(new_data[eligible1 == 1], regformd, class_censed),
        list(new_data[eligible1 == 1], regformn, class_censen)
      )

      if(numCores == 1) {
        # cl <- makeCluster(numCores)
        # m = parLapply(cl, d, weight_lr)
        # stopCluster(cl)
        m = lapply(d, weight_lr)
      } else {
        m = mclapply(d, weight_lr, mc.cores=numCores)
      }

      model1.cense = m[[1]]
      print(summary(model1.cense))
      cense_d0 = data.table( pC_d0 = model1.cense$fitted.values,
                             id = model1.cense$data[, id],
                             period = model1.cense$data[, period])
      # -------------------------- numerator ----------------------
      print("Model for P(cense = 0 |  X, Am1=0) for numerator")
      #--------------------------- eligible0 -----------------------
      model2.cense = m[[2]]
      print(summary(model2.cense))
      cense_n0 = data.table( pC_n0=model2.cense$fitted.values,
                             id = model2.cense$data[, id],
                             period = model2.cense$data[, period])
      # ------------------------- denomirator ---------------------
      print("Model for P(cense = 0 |  X, Am1=1) for denominator")
      # ------------------------ eligible1 -------------------------
      model3.cense = m[[3]]
      print(summary(model3.cense))
      cense_d1 = data.table( pC_d1=model3.cense$fitted.values,
                             id = model3.cense$data[, id],
                             period = model3.cense$data[, period])
      # ------------------------ numerator -------------------------
      print("Model for P(cense = 0 |  X, Am1=1) for numerator")
      # ------------------------- eligible1 -----------------------
      model4.cense = m[[4]]
      print(summary(model4.cense))
      cense_n1 = data.frame( pC_n1 = model4.cense$fitted.values,
                             id = model4.cense$data[, id],
                             period = model4.cense$data[, period])

      cense_0 = cense_d0[cense_n0, on = .(id=id, period=period)]
      cense_1 = cense_d1[cense_n1, on = .(id=id, period=period)]

      new_data = Reduce(function(x,y) merge(x, y,
                                            by = c("id", "period"),
                                            all.x = TRUE, all.y = TRUE),
                        list(new_data, cense_0, cense_1))
      rm(cense_n1, cense_d1, cense_n0, cense_d0, cense_0, cense_1)
    }
  }
  # wt and wtC calculation
  if(any(!is.na(eligible_wts_0))){
    new_data[(am_1 == 0 & eligible_wts_0 == 1 & treatment == 0 & !is.na(p0_n) & !is.na(p0_d)),
             wt := (1.0-p0_n)/(1.0-p0_d)]
    new_data[(am_1 == 0 & eligible_wts_0 == 1 & treatment == 1 & !is.na(p0_n) & !is.na(p0_d)),
             wt := p0_n/p0_d]
    new_data[(am_1 == 0 & eligible_wts_0 == 0), wt := 1.0]
  }else{
    new_data[(am_1 == 0 & treatment == 0 & !is.na(p0_n) & !is.na(p0_d)),
             wt := (1.0-p0_n)/(1.0-p0_d)]
    new_data[(am_1 == 0 & treatment == 1 & !is.na(p0_n) & !is.na(p0_d)),
             wt := p0_n/p0_d]
  }
  if(any(!is.na(eligible_wts_1))){
    new_data[(am_1 == 1 & eligible_wts_1 == 1 &treatment == 0 & !is.na(p1_n) & !is.na(p1_d)),
             wt := (1.0-p1_n)/(1.0-p1_d)]
    new_data[(am_1 == 1 & eligible_wts_1 == 1 & treatment == 1 & !is.na(p1_n) & !is.na(p1_d)),
             wt := p1_n/p1_d]
    new_data[(am_1 == 1 & eligible_wts_1 == 0), wt := 1.0]
  }else{
    new_data[(am_1 == 1 & treatment == 0 & !is.na(p1_n) & !is.na(p1_d)),
             wt := (1.0-p1_n)/(1.0-p1_d)]
    new_data[(am_1 == 1 & treatment == 1 & !is.na(p1_n) & !is.na(p1_d)),
             wt := p1_n/p1_d]
  }

  if(is.na(cense)){
    new_data[, wtC := 1.0]
  }else{
    #new_data[, pC_d := as.numeric(NA)]
    #new_data[, pC_n := as.numeric(NA)]
    if(pool_cense == 0){
      new_data[am_1 == 0, ':='(pC_n=pC_n0, pC_d=pC_d0)]
      new_data[am_1 == 1, ':='(pC_n=pC_n1, pC_d=pC_d1)]
    }
    new_data[is.na(pC_d), pC_d := 1]
    new_data[is.na(pC_n), pC_n := 1]
    new_data[, wtC := pC_n/pC_d]
  }
  new_data[, wt := wt * wtC]
  sw_data <- new_data
  rm(new_data)
  gc()
  return(sw_data)
}

