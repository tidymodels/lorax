# Combine multiple R expressions into a single composite expression

This function takes a list of R expressions and combines them using a
logical operator to create a single composite expression. It is useful
for building complete rule paths by combining individual split
conditions from tree-based models.

## Usage

``` r
combine_rule_elements(exprs, operator = "&")
```

## Arguments

- exprs:

  A list of R expressions to combine. Each element must be a language
  object (expression or symbol). The list can be empty (returns `TRUE`),
  contain a single expression (returns unchanged), or multiple
  expressions (combines with operator).

- operator:

  A character string specifying the logical operator to use:

  - `"&"` (default): combines expressions with AND logic.

  - `"|"`: combines expressions with OR logic.

## Value

An R expression object that combines all input expressions. Returns
`TRUE` for empty list, the single expression for length-1 list, or a
nested expression for multiple elements.

## Examples

``` r
# Basic AND combination
expr1 <- rlang::expr(x > 5)
expr2 <- rlang::expr(y < 10)
combine_rule_elements(list(expr1, expr2))
#> x > 5 & y < 10

# OR operator
combine_rule_elements(list(expr1, expr2), operator = "|")
#> x > 5 | y < 10

# Integration with rect_split_to_expr()
split1 <- list(column = "age", value = 30, operator = ">=")
split2 <- list(column = "income", value = 50000, operator = ">")
exprs <- list(
  rect_split_to_expr(split1),
  rect_split_to_expr(split2)
)
rule <- combine_rule_elements(exprs)

# Evaluate with data
test_data <- data.frame(age = 35, income = 60000)
eval(rule, test_data)
#> [1] TRUE

# Edge cases
combine_rule_elements(list()) # returns TRUE
#> [1] TRUE
combine_rule_elements(list(rlang::expr(x > 0))) # returns x > 0
#> x > 0
```
