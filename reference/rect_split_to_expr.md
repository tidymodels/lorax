# Convert a rectangular split to an R expression

This function converts a split condition from a tree-based model into an
valid R expression. It is primarily used as a building block for
[`extract_rules()`](https://lorax.tidymodels.org/reference/extract_rules.md)
to construct paths to terminal nodes.

## Usage

``` r
rect_split_to_expr(split)
```

## Arguments

- split:

  A named list with three required elements:

  - `column`: character string - variable name for the split.

  - `value`: numeric, character, or character vector - the split.
    threshold/value(s)

  - `operator`: character string - one of: `<`, `<=`, `>`, `>=`, `==`,.
    `%in%`

## Value

An R expression object that can be evaluated.

## Examples

``` r
# Numeric comparison
rect_split_to_expr(list(column = "age", value = 25, operator = "<"))
#> age < 25

# Single character value uses ==
rect_split_to_expr(list(column = "color", value = "red", operator = "=="))
#> color == "red"

# Multiple character values use %in%
rect_split_to_expr(
  list(column = "color", value = c("red", "blue"), operator = "%in%")
)
#> color %in% c("red", "blue")

# Evaluate the expression
expr <- rect_split_to_expr(list(column = "age", value = 30, operator = ">="))
test_data <- data.frame(age = c(20, 30, 40))
test_data[eval(expr, test_data), ]
#> [1] 30 40
```
