# cran-comments

## Submission

This is a new submission. `slxr` implements Spatial-X (SLX) regression
models following Wimpy, Whitten, and Williams (2021)
<doi:10.1086/710089>.

## R CMD check results

0 errors | 0 warnings | 1 note

- Maintainer: 'Cameron Wimpy <cwimpy@astate.edu>'
- New submission
- Possibly misspelled words in DESCRIPTION: 'SLX', 'TSLS', 'Whitten'.
  These are technical acronyms (Spatial-X, temporally-lagged spatial
  lag) and a co-author surname.

## Test environments

- local macOS 15.4, R 4.5.0
- GitHub Actions:
  - macOS-latest,   R release
  - windows-latest, R release
  - ubuntu-latest,  R devel, R release, R oldrel-1
- win-builder (devel)

All environments return 0 errors and 0 warnings. The single NOTE on
win-builder is the new-submission/spell-check message documented
above.

## Downstream dependencies

This is a new package with no reverse dependencies.
