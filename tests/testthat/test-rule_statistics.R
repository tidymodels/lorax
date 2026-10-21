test_that("count_rule_terms() counts conjuncts", {
  expect_identical(count_rule_terms(rlang::expr(TRUE)), 0L)
  expect_identical(count_rule_terms(rlang::expr(a > 1)), 1L)
  expect_identical(count_rule_terms(rlang::expr(is.na(a))), 1L)
  expect_identical(count_rule_terms(rlang::expr(a > 1 & b < 2 & a < 5)), 3L)
  expect_identical(
    count_rule_terms(rlang::expr(a > 1 & (b < 2 & c %in% c("x", "y")))),
    3L
  )
  expect_identical(
    count_rule_terms(rlang::expr(0.5 * a + 0.2 * b - 0.1 * c < 1)),
    1L
  )
})

test_that("add_rule_statistics() computes per-rule statistics", {
  rules <- tibble::tibble(
    id = 1:4,
    rules = list(
      rlang::expr(TRUE),
      rlang::expr(a > 1 & b < 2 & a < 5),
      rlang::expr(c %in% c("x", "y") & 0.5 * a + 0.2 * d < 1),
      rlang::expr(is.na(a))
    )
  )
  res <- add_rule_statistics(rules)

  expect_named(
    res,
    c("id", "rules", "num_term_nodes", "num_rule_terms", "num_rule_predictors")
  )
  expect_identical(res$num_term_nodes, rep(4L, 4))
  expect_identical(res$num_rule_terms, c(0L, 3L, 2L, 1L))
  expect_identical(res$num_rule_predictors, c(0L, 2L, 3L, 1L))
})

test_that("add_rule_statistics() counts terminal nodes by tree or committee", {
  rules <- tibble::tibble(
    tree = c(2L, 2L, 5L, 2L, 5L),
    id = 1:5,
    rules = rep(list(rlang::expr(a > 1)), 5)
  )
  expect_identical(
    add_rule_statistics(rules)$num_term_nodes,
    c(3L, 3L, 2L, 3L, 2L)
  )

  names(rules)[1] <- "committee"
  expect_identical(
    add_rule_statistics(rules)$num_term_nodes,
    c(3L, 3L, 2L, 3L, 2L)
  )
})

test_that("maybe_add_rule_statistics() respects add_statistics", {
  rules <- tibble::tibble(id = 1L, rules = list(rlang::expr(a > 1)))
  expect_identical(maybe_add_rule_statistics(rules, FALSE), rules)
  expect_named(
    maybe_add_rule_statistics(rules, TRUE),
    c("id", "rules", "num_term_nodes", "num_rule_terms", "num_rule_predictors")
  )
})
