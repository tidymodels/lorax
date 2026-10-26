#' Methods for tidymodels objects
#'
#' Fitted \pkg{parsnip} model objects (`model_fit`) and fitted \pkg{workflows}
#' objects (`workflow`) are unwrapped with [hardhat::extract_fit_engine()] and
#' the generic is then called on the underlying engine model. All other
#' arguments, such as `tree`, `add_statistics`, or `data`, are passed to the
#' method for the engine model; see the documentation for that model's method.
#'
#' For `as.party()`, engines that need the training data (e.g., xgboost) require
#' it via `data`. For workflows, this should be the preprocessed predictors that
#' were given to the engine.
#'
#' @param x,obj,object A fitted `model_fit` or `workflow` object.
#' @param ... Other arguments passed to the method for the engine model.
#'
#' @return The result of the generic applied to the engine model.
#'
#' @examples
#' if (rlang::is_installed(c("parsnip", "ranger"))) {
#'   library(parsnip)
#'
#'   rf_fit <-
#'     rand_forest(trees = 5) |>
#'     set_engine("ranger") |>
#'     set_mode("regression") |>
#'     fit(mpg ~ ., data = mtcars)
#'
#'   num_ensemble_members(rf_fit)
#'   extract_rules(rf_fit, tree = 1:2)
#' }
#' @name tidymodels-methods
NULL

extract_engine <- function(x) {
  hardhat::extract_fit_engine(x)
}

#' @rdname tidymodels-methods
#' @export
extract_rules.model_fit <- function(x, ...) {
  extract_rules(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
extract_rules.workflow <- function(x, ...) {
  extract_rules(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
active_predictors.model_fit <- function(x, ...) {
  active_predictors(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
active_predictors.workflow <- function(x, ...) {
  active_predictors(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
num_ensemble_members.model_fit <- function(x, ...) {
  num_ensemble_members(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
num_ensemble_members.workflow <- function(x, ...) {
  num_ensemble_members(extract_engine(x), ...)
}

#' @rdname tidymodels-methods
#' @export
as.party.model_fit <- function(obj, ...) {
  partykit::as.party(extract_engine(obj), ...)
}

#' @rdname tidymodels-methods
#' @export
as.party.workflow <- function(obj, ...) {
  partykit::as.party(extract_engine(obj), ...)
}

#' @rdname tidymodels-methods
#' @export
var_imp.model_fit <- function(object, ...) {
  generics::var_imp(extract_engine(object), ...)
}

#' @rdname tidymodels-methods
#' @export
var_imp.workflow <- function(object, ...) {
  generics::var_imp(extract_engine(object), ...)
}
