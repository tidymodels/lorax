#' Extract an expression that defines a path to a terminal node
#'
#' A rule is a logical expression of predictor variables that reflects which
#' data are contained in or sent to a terminal node in a tree-based model. Rules
#' can take any form but, for most trees, they are simple statements such as
#' `x < 1.2`, `y == "red"`, or `z %in% c("blue", "green")`.
#'
#' @param x A object
#' @param add_statistics A single logical. If `TRUE`, two integer columns
#'   are added to the results:
#'   * `num_rule_terms`: the number of conditions joined by `&` in the rule.
#'   * `num_rule_predictors`: the number of unique predictors in the rule.
#'
#'   A rule of `TRUE` (a tree with no splits) has zero terms and predictors.
#' @param ... Other arguments passed to methods
#'
#' @return A data frame with column `rules` (an R expression) and `id` (an
#' identifier).
#'
#' @examples
#' fit <- partykit::ctree(Species ~ ., data = iris)
#' extract_rules(fit)
#'
#' @export
extract_rules <- function(x, ...) {
  UseMethod("extract_rules")
}

# ------------------------------------------------------------------------------

#' Extract the active features from a tree
#'
#' If a tree does not use a predictor in the training set in any of its splits
#' it is functionally independent of the prediction function. This generic
#' returns a data frame containing character vector of predictor names that
#' were used in at least one split.
#'
#' @param x A object
#' @param ... Other arguments passed to methods
#'
#' @return A tibble with list column `active_predictors` containing a character
#' vector of predictors.
#'
#' @examples
#' if (rlang::is_installed(c("rpart", "palmerpenguins"))) {
#'   data(penguins, package = "palmerpenguins")
#'   penguins <- na.omit(penguins)
#'
#'   # Fit a tree
#'   tree <- rpart::rpart(species ~ ., data = penguins)
#'   tree
#'
#'   # Extract active predictors
#'   active_predictors(tree)
#'
#'   # Only primary splits are included - competing and surrogate splits
#'   # are excluded since they don't affect predictions
#' }
#'
#' # C5.0 single tree
#' if (rlang::is_installed(c("C50", "palmerpenguins"))) {
#'   data(penguins, package = "palmerpenguins")
#'   penguins <- na.omit(penguins)
#'
#'   # Tree-based model
#'   c5_tree <- C50::C5.0(species ~ ., data = penguins)
#'   active_predictors(c5_tree)
#'
#'   # Boosted model - extract from multiple trials
#'   c5_boost <- C50::C5.0(species ~ ., data = penguins, trials = 5)
#'   active_predictors(c5_boost, tree = 1:3)
#'
#'   # Rule-based model
#'   c5_rules <- C50::C5.0(species ~ ., data = penguins, rules = TRUE)
#'   active_predictors(c5_rules)
#' }
#'
#' @export
active_predictors <- function(x, ...) {
  UseMethod("active_predictors")
}

# ------------------------------------------------------------------------------

#' Count the number of members in an ensemble
#'
#' Ensembles of trees or rules, such as random forests or boosted models,
#' contain multiple models. This generic returns how many there are. For most
#' models this is the number of trees. For C5.0 models it is the number of
#' boosting trials and, for Cubist models, the number of committees. For
#' multiclass boosted models (e.g., from \pkg{xgboost} and \pkg{lightgbm}), the
#' count is the total number of trees across all classes.
#'
#' The value is the largest index that can be passed to the `tree` (or
#' `committee`) argument of methods such as [extract_rules()] and
#' [active_predictors()].
#'
#' Methods are only available for model classes that can be ensembles; single
#' tree models (e.g., from `rpart::rpart()`) do not have a method.
#'
#' @param x A object
#' @param ... Other arguments passed to methods
#'
#' @return A single integer.
#'
#' @examples
#' if (rlang::is_installed("ranger")) {
#'   rf <- ranger::ranger(mpg ~ ., data = mtcars, num.trees = 10)
#'   num_ensemble_members(rf)
#' }
#'
#' @export
num_ensemble_members <- function(x, ...) {
  UseMethod("num_ensemble_members")
}
