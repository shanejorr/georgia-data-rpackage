# Recorded fixtures: shorten the API's URL prefix so every fixture path
# stays well under R CMD check's 100-byte limit, and keep only the
# response headers the package reads.
if (requireNamespace("httptest2", quietly = TRUE)) {
  httptest2::set_redactor(gcd_redactor)
}
