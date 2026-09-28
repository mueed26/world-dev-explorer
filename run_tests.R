# Run the unit tests from the project root: Rscript run_tests.R
testthat::test_dir("tests/testthat", reporter = "progress", stop_on_failure = TRUE)
