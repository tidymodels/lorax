rule_near_boundary <- function(rule, data, tol = 1e-8) {
  comparisons <- list()
  collect <- function(e) {
    if (rlang::is_call(e, "&")) {
      collect(e[[2]])
      collect(e[[3]])
    } else {
      comparisons[[length(comparisons) + 1]] <<- e
    }
  }
  collect(rule)

  near <- rep(FALSE, nrow(data))
  for (comparison in comparisons) {
    score <- eval(comparison[[2]], data)
    threshold <- eval(comparison[[3]], data)
    near <- near | abs(score - threshold) < tol * max(1, abs(threshold))
  }
  near
}
