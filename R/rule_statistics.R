add_rule_statistics <- function(x) {
  x$num_rule_terms <- vapply(x$rules, count_rule_terms, integer(1))
  x$num_rule_predictors <- vapply(
    x$rules,
    \(r) length(all.vars(r)),
    integer(1)
  )
  x
}

count_rule_terms <- function(expr) {
  if (is.call(expr) && identical(expr[[1]], quote(`&`))) {
    return(count_rule_terms(expr[[2]]) + count_rule_terms(expr[[3]]))
  }
  if (is.call(expr) && identical(expr[[1]], quote(`(`))) {
    return(count_rule_terms(expr[[2]]))
  }
  if (isTRUE(expr)) {
    return(0L)
  }
  1L
}

maybe_add_rule_statistics <- function(x, add_statistics) {
  if (!add_statistics) {
    return(x)
  }
  add_rule_statistics(x)
}
