# Convert a rule expression to a readable text format

This function formats R expressions representing rules from tree-based
models as character strings. It provides options for formatting numeric
values, displaying rules as bulleted lists, and controlling output
width.

## Usage

``` r
rule_text(
  expr,
  bullets = FALSE,
  digits = 4,
  max_width = Inf,
  key = NULL,
  max_group_nchar = Inf
)
```

## Arguments

- expr:

  An R expression to format. Typically created by
  [`rect_split_to_expr()`](https://lorax.tidymodels.org/reference/rect_split_to_expr.md)
  or
  [`combine_rule_elements()`](https://lorax.tidymodels.org/reference/combine_rule_elements.md).

- bullets:

  Logical indicating whether to break apart rule elements and display as
  a bulleted list. If `TRUE`, splits on `&` operators and creates a
  bulleted list with each condition on a new line. If `FALSE` (default),
  returns as a single line.

- digits:

  Integer number of significant digits to use when formatting numeric
  values in the rule. Default is 4.

- max_width:

  Maximum width for the output when `bullets = FALSE`. If the formatted
  rule exceeds this width, it will be truncated with `..` appended. The
  `..` is included in the width count. Default is `Inf` (no truncation).

- key:

  Optional data frame or tibble with columns `original` and `label`
  (both character). When provided, variable names matching values in
  `original` are substituted with corresponding values in `label` in the
  printed output. The `original` column must not contain duplicates. If
  a variable name is not in `key$original`, it remains unchanged.

- max_group_nchar:

  Maximum number of characters for value lists in `%in%` operations.
  When the total character count of values in a `c(...)` vector exceeds
  this limit, the values are replaced with `{X values}` where X is the
  count. Default is `Inf` (no abbreviation). Character count includes
  quotes and separators as they appear in deparsed output.

## Value

A character string containing the formatted rule. When `bullets = TRUE`,
conditions are separated by newlines with bullet markers.

## Examples

``` r
# Simple numeric rule
rule1 <- rlang::expr(age >= 30)
rule_text(rule1)
#> [1] "age >= 30"

# Multiple conditions
rule2 <- rlang::expr(age >= 30 & income > 50000)
rule_text(rule2)
#> [1] "age >= 30 & income > 50000"

# Bulleted format
cat(rule_text(rule2, bullets = TRUE), "\n")
#> * age >= 30
#> * income > 50000 

# Control numeric precision
rule3 <- rlang::expr(x > 1.23456789)
rule_text(rule3, digits = 2)
#> [1] "x > 1.2"
rule_text(rule3, digits = 6)
#> [1] "x > 1.23457"

# Truncate long rules
rule4 <- rlang::expr(very_long_variable_name > 100 & another_long_name < 50)
rule_text(rule4, max_width = 30)
#> [1] "very_long_variable_name > 1..."

# With label substitution
expr <- rlang::expr(pct_owed > 0.5 & amount < 1000)
key <- tibble::tibble(
  original = c("pct_owed", "amount"),
  label = c("percentage owed by customer", "total amount")
)
rule_text(expr, key = key)
#> [1] "percentage owed by customer > 0.5 & total amount < 1000"

# Integration with other helpers
split1 <- list(column = "age", value = 30.5, operator = ">=")
split2 <- list(column = "income", value = 50000, operator = ">")
split3 <- list(column = "city", value = c("NYC", "LA"), operator = "%in%")
rule <- combine_rule_elements(list(
  rect_split_to_expr(split1),
  rect_split_to_expr(split2),
  rect_split_to_expr(split3)
))
cat(rule_text(rule, bullets = TRUE), "\n")
#> * age >= 30.5
#> * income > 50000
#> * city %in% c("NYC", "LA") 

# Abbreviate long value lists
split4 <- list(
  column = "county",
  value = c("adams", "benton", "chelan", "clallam"),
  operator = "%in%"
)
rule_long <- rect_split_to_expr(split4)
rule_text(rule_long) # Full list
#> [1] "county %in% c(\"adams\", \"benton\", \"chelan\", \"clallam\")"
rule_text(rule_long, max_group_nchar = 20) # Abbreviated
#> [1] "county %in% {4 values}"
```
