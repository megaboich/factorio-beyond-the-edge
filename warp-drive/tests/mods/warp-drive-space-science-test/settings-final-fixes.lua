local impatient = data.raw["bool-setting"]["warp-drive-severely-impatient"]
if not impatient then
  error("WARP_TEST_FAIL: severely impatient runtime setting is missing")
end

-- The local branch run doubles as coverage for the optional 1,000x runtime multiplier.
impatient.default_value = true
