# Methods for bagged trees from the baguette package (`bag_tree()` with the
# "rpart" or "C5.0" engine). The ensemble members are single trees stored as
# parsnip model fits in `model_df`, so `tree` is the index of the member.

bagger_check <- function(x, call = rlang::caller_env()) {
  rlang::check_installed("baguette", call = call)
  engine <- x$base_model[1]
  if (!engine %in% c("CART", "C5.0")) {
    cli::cli_abort(
      "Only bagged {.val CART} and {.val C5.0} trees are supported, not {.val {engine}}.",
      call = call
    )
  }
  invisible(x)
}

bagger_check_tree <- function(tree, x, call = rlang::caller_env()) {
  if (!is.numeric(tree) || !all(tree == as.integer(tree))) {
    cli::cli_abort(
      "{.arg tree} must be an integer vector, not {.obj_type_friendly {tree}}.",
      call = call
    )
  }
  tree <- as.integer(tree)
  num_trees <- nrow(x$model_df)
  if (any(tree < 1L) || any(tree > num_trees)) {
    cli::cli_abort(
      "{.arg tree} values must be between 1 and {num_trees}.",
      call = call
    )
  }
  tree
}

bagger_member <- function(x, i) {
  x$model_df$model[[i]]$fit
}

#' @rdname num_ensemble_members
#' @export
num_ensemble_members.bagger <- function(x, ...) {
  bagger_check(x)
  nrow(x$model_df)
}

# Members are fit on bootstrap samples that are not kept, so the model frame
# and node assignments are rebuilt from the supplied data.
bagger_rpart_party <- function(
  member,
  data,
  outcome,
  call = rlang::caller_env()
) {
  rlang::check_installed("rpart", call = call)
  predictors <- attr(member$terms, "term.labels")
  missing_cols <- setdiff(c(predictors, outcome), names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "{.arg data} is missing column{?s} {.val {missing_cols}}.",
      call = call
    )
  }

  data[[".outcome"]] <- data[[outcome]]
  mf <- stats::model.frame(
    member$terms,
    data = data,
    na.action = stats::na.pass
  )

  # A first pass finds the terminal node of each row, which is used to set the
  # fitted values (and the missing value routing) in the second pass.
  member$model <- mf
  member$where <- rep(which(member$frame$var == "<leaf>")[1], nrow(mf))
  first <- partykit::as.party(member)
  node_ids <- stats::predict(first, newdata = mf, type = "node")
  member$where <- node_ids

  partykit::as.party(member)
}

#' Convert a bagged tree to a party object
#'
#' Convert a single tree from a bagged model created by \pkg{baguette} (e.g.,
#' `parsnip::bag_tree()`) to a party object for use with \pkg{partykit}
#' visualization and analysis tools. Both the "rpart" and "C5.0" engines are
#' supported.
#'
#' @param obj A `bagger` object, which is the `fit` element of a fitted
#'   `bag_tree()` model.
#' @param tree A single integer specifying which tree (ensemble member) to
#'   convert. Must be between 1 and the number of bagged trees.
#' @param data A data frame with the training data, including the outcome. The
#'   bootstrap samples used to fit each tree are not saved, so this is used for
#'   the node assignments and predictions in the party object.
#' @param ... Not currently used.
#'
#' @return A `party` object from the \pkg{partykit} package.
#'
#' @examplesIf rlang::is_installed(c("baguette", "parsnip", "rpart", "palmerpenguins"))
#' data(penguins, package = "palmerpenguins")
#' penguins <- na.omit(penguins)
#'
#' set.seed(1)
#' bag_fit <- parsnip::bag_tree(mode = "classification", tree_depth = 3) |>
#'   parsnip::set_engine("rpart", times = 3) |>
#'   parsnip::fit(species ~ ., data = penguins)
#'
#' as.party(bag_fit$fit, tree = 2L, data = penguins)
#'
#' @export
as.party.bagger <- function(obj, tree = 1L, data = NULL, ...) {
  bagger_check(obj)
  if (is.null(data)) {
    cli::cli_abort("{.arg data} is required for {.fn as.party.bagger}.")
  }
  if (!is.numeric(tree) || length(tree) != 1) {
    cli::cli_abort(
      "{.arg tree} must be a single integer, not {.obj_type_friendly {tree}}."
    )
  }
  tree <- bagger_check_tree(tree, obj)

  member <- bagger_member(obj, tree)
  if (obj$base_model[1] == "C5.0") {
    return(as.party(member, tree = 1L, data = data))
  }

  outcome <- names(obj$blueprint$ptypes$outcomes)
  bagger_rpart_party(member, data, outcome)
}

#' @rdname extract_rules
#' @param tree Integer vector specifying which trees (ensemble members) to
#'   extract rules from. Default is `1L` for the first tree. Values must be
#'   between 1 and the number of bagged trees.
#' @export
extract_rules.bagger <- function(x, tree = 1L, add_statistics = FALSE, ...) {
  check_bool(add_statistics)
  bagger_check(x)
  tree <- bagger_check_tree(tree, x)

  results <- lapply(tree, function(i) {
    res <- extract_rules(bagger_member(x, i))
    res$tree <- rep(i, nrow(res))
    res[c("id", "rules", "tree")]
  })

  res <- dplyr::bind_rows(results) |>
    dplyr::arrange(tree, id)
  engine_class <- ifelse(x$base_model[1] == "CART", "rpart", "C5.0")
  engine_class <- paste0("rule_set_", engine_class)
  class(res) <- c(
    engine_class,
    "rule_set",
    "tbl_df",
    "tbl",
    "data.frame"
  )

  maybe_add_rule_statistics(res, add_statistics)
}

#' @rdname active_predictors
#' @param tree Integer vector specifying which trees (ensemble members) to
#'   extract active predictors from. Default is `1L` for the first tree. Values
#'   must be between 1 and the number of bagged trees.
#' @export
active_predictors.bagger <- function(x, tree = 1L, ...) {
  bagger_check(x)
  tree <- bagger_check_tree(tree, x)

  results <- lapply(tree, function(i) {
    vars <- active_predictors(bagger_member(x, i))$active_predictors[[1]]
    new_active_predictors(vars, tree = i)
  })

  dplyr::bind_rows(results)
}
