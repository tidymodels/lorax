#' Extract rules from a party object
#'
#' Extract interpretable decision rules from a \pkg{partykit} `party` or
#' `constparty` object. Each terminal node becomes one rule representing the
#' path from root to that leaf.
#'
#' @inheritParams extract_rules
#' @param x A `party` or `constparty` object from the \pkg{partykit} package.
#' @param ... Not currently used.
#'
#' @return A tibble with class `c("rule_set_party", "rule_set")` and columns:
#'   * `id`: integer, the terminal node ID.
#'   * `rules`: list of R expressions, one per terminal node.
#'
#' @examples
#' fit <- partykit::ctree(Species ~ ., data = iris)
#' extract_rules(fit)
#'
#' @export
extract_rules.party <- function(x, add_statistics = FALSE, ...) {
  check_bool(add_statistics)
  collected <- party_collect_rules(x)

  tibble::tibble(
    id = as.integer(collected$ids),
    rules = collected$rules
  ) |>
    dplyr::arrange(id) |>
    tibble::new_tibble(class = c("rule_set_party", "rule_set")) |>
    maybe_add_rule_statistics(add_statistics)
}

# Internal helper: build the split expression for one child of a node
party_split_expr <- function(sp, kid_position, var_names, level_sets) {
  var_idx <- partykit::varid_split(sp)
  var_name <- var_names[var_idx]
  breaks <- partykit::breaks_split(sp)

  if (!is.null(breaks)) {
    ops <- c("<", ">=")
    if (partykit::right_split(sp)) {
      ops <- c("<=", ">")
    }
    split_info <- list(
      column = var_name,
      value = breaks,
      operator = ops[kid_position]
    )
  } else {
    index <- partykit::index_split(sp)
    levels_for_kid <- level_sets[[var_idx]][which(index == kid_position)]
    operator <- "%in%"
    if (length(levels_for_kid) == 1) {
      operator <- "=="
    }
    split_info <- list(
      column = var_name,
      value = levels_for_kid,
      operator = operator
    )
  }

  rect_split_to_expr(split_info)
}

# Internal helper: walk the tree once from the root, carrying the split
# expressions down and collecting one rule per terminal node.
party_collect_rules <- function(x) {
  var_names <- names(x$data)
  level_sets <- lapply(x$data, levels)
  ids <- integer()
  rules <- list()

  walk <- function(node, exprs) {
    kids <- partykit::kids_node(node)
    if (is.null(kids)) {
      ids[[length(ids) + 1L]] <<- partykit::id_node(node)
      rules[[length(rules) + 1L]] <<- combine_rule_elements(exprs)
      return(invisible(NULL))
    }
    sp <- partykit::split_node(node)
    for (k in seq_along(kids)) {
      expr <- party_split_expr(sp, k, var_names, level_sets)
      walk(kids[[k]], c(exprs, list(expr)))
    }
    invisible(NULL)
  }

  walk(partykit::node_party(x), list())
  list(ids = ids, rules = rules)
}

# Internal helper: extract variable name from a node
party_extract_var_name <- function(node, x) {
  sp <- partykit::split_node(node)

  # Only extract variable if split exists (some non-terminal nodes may not have splits)
  if (!is.null(sp)) {
    var_idx <- partykit::varid_split(sp)
    names(x$data)[var_idx]
  } else {
    character(0)
  }
}

#' @rdname active_predictors
#' @export
active_predictors.party <- function(x, ...) {
  rlang::check_installed("partykit")

  # Get all non-terminal nodes (nodes with splits)
  non_terminal_ids <- partykit::nodeids(x, terminal = FALSE)

  # Extract variable names from each split
  if (length(non_terminal_ids) == 0) {
    # No non-terminal nodes means no splits
    active_vars <- character(0)
  } else {
    nodes <- partykit::nodeapply(x, ids = non_terminal_ids, by_node = TRUE)
    active_vars_list <- lapply(nodes, party_extract_var_name, x = x)

    # Combine all variables
    active_vars <- unique(unlist(active_vars_list, use.names = FALSE))
  }

  # Use constructor to create result
  new_active_predictors(active_vars)
}

# ------------------------------------------------------------------------------
# Variable importance for party

#' @export
#' @rdname lorax_var_imp
var_imp.party <- function(object, complete = TRUE, ...) {
  rlang::check_installed("partykit")

  # Use partykit::varimp() to compute variable importance
  imp <- partykit::varimp(object, ...)

  # Convert to tibble
  res <- tibble::enframe(imp)
  names(res) <- c("term", "estimate")

  if (complete) {
    # Get all predictor names from the model
    pred_names <- all.vars(object$terms)[-attr(object$terms, "response")]
    res <- complete_results(res, pred_names)
  }

  res
}
