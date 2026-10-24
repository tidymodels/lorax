#' Extract rules from an rpart model
#'
#' Extract interpretable decision rules from an \pkg{rpart} decision tree.
#' Each terminal node becomes one rule representing the path from root to
#' that leaf.
#'
#' @inheritParams extract_rules
#' @param x An `rpart` object from the \pkg{rpart} package.
#' @param ... Not currently used.
#'
#' @return A tibble with class `c("rule_set_rpart", "rule_set")` and columns:
#'   * `id`: integer, the terminal node ID.
#'   * `rules`: list of R expressions, one per terminal node.
#'
#' @examplesIf rlang::is_installed("rpart")
#' fit <- rpart::rpart(Species ~ ., data = iris)
#' extract_rules(fit)
#'
#' @export
extract_rules.rpart <- function(x, add_statistics = FALSE, ...) {
  check_bool(add_statistics)
  rlang::check_installed("rpart")
  collected <- rpart_collect_rules(x)

  tibble::tibble(
    id = as.integer(collected$ids),
    rules = collected$rules
  ) |>
    dplyr::arrange(id) |>
    tibble::new_tibble(class = c("rule_set_rpart", "rule_set")) |>
    maybe_add_rule_statistics(add_statistics)
}

# rpart-specific helper: walk the tree once from the root (node 1, children
# 2 * id and 2 * id + 1), carrying the split expressions down to each leaf
rpart_collect_rules <- function(x) {
  frame_ids <- as.integer(rownames(x$frame))
  is_leaf <- x$frame$var == "<leaf>"

  # Each non-leaf uses 1 + ncompete + nsurrogate rows of the splits matrix, in
  # frame order, so the primary split of a node follows all earlier splits
  splits_used <- 1 + x$frame$ncompete + x$frame$nsurrogate
  splits_used[is_leaf] <- 0
  split_rows <- cumsum(c(0, splits_used))[seq_along(frame_ids)] + 1

  ids <- integer()
  rules <- list()

  walk <- function(node_id, exprs) {
    pos <- match(node_id, frame_ids)
    if (is_leaf[pos]) {
      ids[[length(ids) + 1L]] <<- node_id
      rules[[length(rules) + 1L]] <<- combine_rule_elements(exprs)
      return(invisible(NULL))
    }
    for (child_id in c(2L * node_id, 2L * node_id + 1L)) {
      split_info <- rpart_get_split_info(node_id, child_id, x, split_rows[pos])
      expr <- rect_split_to_expr(split_info)
      walk(child_id, c(exprs, list(expr)))
    }
    invisible(NULL)
  }

  walk(1L, list())
  list(ids = ids, rules = rules)
}

# rpart-specific helper to get split info for a node
rpart_get_split_info <- function(node_id, child_id, x, split_row) {
  # Determine if we go left or right
  is_left <- child_id == 2 * node_id

  # Get variable name for this node's split
  node_row <- as.character(node_id)
  var_name <- x$frame[node_row, "var"]

  ncat <- x$splits[split_row, "ncat"]
  split_index <- x$splits[split_row, "index"]

  # Handle categorical vs numeric splits
  # ncat = -1: standard numeric split (left: <, right: >=)
  # ncat = 1: ordered categorical/numeric split (left: >=, right: <)
  # ncat > 1: categorical split with ncat levels
  if (ncat == -1) {
    # Standard numeric split
    threshold <- split_index
    if (is_left) {
      list(column = var_name, value = threshold, operator = "<")
    } else {
      list(column = var_name, value = threshold, operator = ">=")
    }
  } else if (ncat == 1) {
    # Ordered categorical or reversed numeric split
    threshold <- split_index
    if (is_left) {
      list(column = var_name, value = threshold, operator = ">=")
    } else {
      list(column = var_name, value = threshold, operator = "<")
    }
  } else {
    # Categorical split (ncat > 1)
    # csplit matrix: row = split_index, columns = factor levels
    # values: 1 = left, 3 = right
    csplit_row <- x$csplit[as.integer(split_index), ]

    # Get factor levels for this variable
    # Check if variable is in ordered vector
    if (!is.null(x$ordered) && var_name %in% names(x$ordered)) {
      # For ordered factors, get levels from the data
      # We need to reconstruct levels from the frame
      # For now, use csplit indices as level numbers
      levels_going_direction <- which(
        if (is_left) csplit_row == 1 else csplit_row == 3
      )
    } else {
      # For unordered factors, same approach
      levels_going_direction <- which(
        if (is_left) csplit_row == 1 else csplit_row == 3
      )
    }

    # Convert level indices to actual level names
    # Try to get factor levels from the model's data
    level_names <- rpart_get_factor_levels(var_name, levels_going_direction, x)

    # Return appropriate operator
    if (length(level_names) == 1) {
      list(column = var_name, value = level_names, operator = "==")
    } else {
      list(column = var_name, value = level_names, operator = "%in%")
    }
  }
}

# rpart-specific helper to get factor level names
rpart_get_factor_levels <- function(var_name, level_indices, x) {
  # First try xlevels (fastest)
  if (!is.null(x$xlevels) && var_name %in% names(x$xlevels)) {
    return(x$xlevels[[var_name]][level_indices])
  }

  # Try to get from the model's data via environment
  if (!is.null(x$terms)) {
    env <- attr(x$terms, ".Environment")
    data_name <- as.character(x$call$data)

    if (length(data_name) > 0 && exists(data_name, envir = env)) {
      data <- get(data_name, envir = env)
      if (var_name %in% names(data) && is.factor(data[[var_name]])) {
        return(levels(data[[var_name]])[level_indices])
      }
    }
  }

  # Fallback: use numeric indices as strings
  as.character(level_indices)
}

#' @rdname active_predictors
#' @export
active_predictors.rpart <- function(x, ...) {
  rlang::check_installed("rpart")

  # Extract variables used in splits (excluding leaves)
  all_vars <- x$frame$var
  active_vars <- unique(all_vars[all_vars != "<leaf>"])

  # Use constructor to create result
  new_active_predictors(active_vars)
}

# ------------------------------------------------------------------------------
# Variable importance Wrapper

#' @export
#' @rdname lorax_var_imp
var_imp.rpart <- function(object, complete = TRUE, ...) {
  res <- tibble::enframe(object$variable.importance)
  names(res) <- c("term", "estimate")

  # Ensure term is character (enframe returns integer when input is NULL)
  res$term <- as.character(res$term)

  if (complete) {
    vars <- terms_predictor_names(object$terms)
    res <- complete_results(res, vars)
  }

  res
}
