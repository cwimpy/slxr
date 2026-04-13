# Tidy and glance methods for SLX models

These methods make `slx` objects compatible with the `broom` and
`modelsummary` ecosystems.

## Usage

``` r
# S3 method for class 'slx'
tidy(x, conf.int = FALSE, conf.level = 0.95, ...)

# S3 method for class 'slx'
glance(x, ...)
```

## Arguments

- x:

  An `slx` object.

- conf.int:

  Logical; include confidence intervals?

- conf.level:

  Confidence level.

- ...:

  Unused.

## Examples

``` r
if (FALSE) { # \dontrun{
fit <- slx(y ~ x1 + x2, data = df, W = W, lag = "x1")
broom::tidy(fit)
broom::glance(fit)
} # }
```
