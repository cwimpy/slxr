# Direct, indirect, and total effects from an SLX model

For an SLX model the effects decomposition is trivial — no matrix
inversion, no simulation. For each variable \\x\\ that enters both
directly and as a spatial lag, the direct effect is its OLS coefficient
\\\hat\beta\\ and the indirect effect at order \\k\\ is
\\\hat\theta_k\\. Standard errors come straight from
[`vcov()`](https://rdrr.io/r/stats/vcov.html).

## Usage

``` r
slx_effects(object, by_order = FALSE, conf.level = 0.95)
```

## Arguments

- object:

  An `slx` object returned by
  [`slx()`](https://cwimpy.github.io/slxr/reference/slx.md).

- by_order:

  Logical; if `TRUE`, report indirect effects separately by order of W.
  Default `FALSE` sums across orders for a single indirect effect per
  variable–W combination.

- conf.level:

  Confidence level for reported intervals. Default 0.95.

## Value

A tibble with columns `variable`, `w_name`, `order` (when
`by_order = TRUE`), `type` (direct/indirect/total), `estimate`,
`std.error`, `conf.low`, `conf.high`, `p.value`.

## Examples

``` r
if (FALSE) { # \dontrun{
fit <- slx(y ~ x1 + x2, data = df, W = W, lag = "x1")
slx_effects(fit)
} # }
```
