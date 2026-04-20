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

## Value

`tidy.slx()` returns a
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per model coefficient (both direct and spatial-lag terms)
and columns `term`, `estimate`, `std.error`, `statistic`, and `p.value`.
When `conf.int = TRUE`, `conf.low` and `conf.high` columns are added.

`glance.slx()` returns a one-row
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
summarizing the overall fit, with columns `r.squared`, `adj.r.squared`,
`sigma`, `statistic` (F statistic), `df`, `df.residual`, `nobs`, and
`n_lag_terms` (the number of spatial-lag regressors in the model).

## Examples

``` r
data(defense_burden)
W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                 row_standardize = FALSE)
fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
           data = defense_burden$data, W = W, lag = "civilwar_tm1")
tidy(fit)
#> # A tibble: 4 × 5
#>   term           estimate std.error statistic  p.value
#>   <chr>             <dbl>     <dbl>     <dbl>    <dbl>
#> 1 (Intercept)       0.460    0.136      3.38  9.08e- 4
#> 2 milex_tm1        -0.238    0.0233   -10.2   1.71e-19
#> 3 civilwar_tm1     -1.18     0.571     -2.06  4.09e- 2
#> 4 W.civilwar_tm1    0.171    0.836      0.204 8.39e- 1
glance(fit)
#> # A tibble: 1 × 8
#>   r.squared adj.r.squared sigma statistic    df df.residual  nobs n_lag_terms
#>       <dbl>         <dbl> <dbl>     <dbl> <dbl>       <int> <int>       <int>
#> 1     0.404         0.394  1.46      39.6     3         175   179           1
```
