We are also allowed to write lib interface files at each level.
  $ dune build
  File "lib/dune", line 1, characters 17-26:
  1 | (include_subdirs qualified)
                       ^^^^^^^^^
  Error: Unknown value qualified
  Hint: did you mean unqualified?
  [1]
