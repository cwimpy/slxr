# Plot how indirect effects decay across orders of W

For SLX models fit with higher-order lags (`order = 1:k`), shows the
size of the indirect effect at each order, with confidence intervals.

## Usage

``` r
slx_plot_decay(fit, variables = NULL, conf.level = 0.95)
```

## Arguments

- fit:

  An `slx` model fit with higher-order `W` terms.

- variables:

  Optional character vector restricting to specific lagged variables.
  Default plots all.

- conf.level:

  Confidence level.

## Value

A `ggplot` object.
