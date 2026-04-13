# Defense burden panel, 1951-2008

The full country-year panel underlying Wimpy, Whitten, and Williams
(2021) Table 3, Model 3. Includes a tibble of 7,661 country-year
observations and three named lists of row-standardized sparse weights
matrices, one matrix per year, encoding contiguity, alliance, and
defense-pact connections.

## Usage

``` r
defense_burden_panel
```

## Format

A named list:

- `data`:

  A tibble with 7,661 rows and the same 12 columns as
  [defense_burden](https://cwimpy.github.io/slxr/reference/defense_burden.md)`$data`,
  but spanning 1951-2008.

- `W_contig`:

  Named list of 58 sparse matrices, one per year, keyed by year as a
  string. Each matrix is row-standardized and contains the countries
  observed in that year.

- `W_alliance`:

  As above, for alliance ties.

- `W_defense`:

  As above, for mutual defense pacts.

## Source

Wimpy, Whitten, and Williams (2021) replication archive, Journal of
Politics Dataverse. [doi:10.1086/710089](https://doi.org/10.1086/710089)

## Details

Sample excludes observations with missing covariates. Panel is
unbalanced: between 63 and 187 countries per year.

## See also

[defense_burden](https://cwimpy.github.io/slxr/reference/defense_burden.md)
for the 1995 cross-section.

## Examples

``` r
data(defense_burden_panel)
names(defense_burden_panel$W_contig)[1:5]
#> [1] "1951" "1952" "1953" "1954" "1955"
dim(defense_burden_panel$W_contig[["1990"]])
#> [1] 144 144
```
