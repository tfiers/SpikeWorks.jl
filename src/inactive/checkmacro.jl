"""
    @assert ex [msg]

Fast like `@assert`¹, but showing values like `@test`.

This macro behaves like `@assert` (i.e. shows stacktrace on error,
executes no extra code, and can be disabled with an optimization flag);
but if the assertion fails, uses `@test`'s nice display of _evaluated_
components of the test expression.

¹To benchmark still, though.

The optional `msg` is what gets shown after `"AssertionError: "`

## Example:
```
julia> "Calculate the length of a square's sides"
       function sidelength(area)
           @assert area ≥ 0 "Imaginary squares not supported"
           ℓ = √area
       end;

julia> sidelength(2)
1.4142135623730951

julia> sidelength(-1)
Test Failed at REPL[2]:2
  Expression: area ≥ 0
   Evaluated: -1 ≥ 0
ERROR: AssertionError: Imaginary squares not supported
Stacktrace:
 [1] sidelength(area::Int64)
   @ Main .\\REPL[1]:3
 [2] top-level scope
   @ REPL[3]:1
"""
macro check(ex, msg = "[see test result above]")
    # For useful stacktraces:
    # have macrocalls point to original source (instead of this macro)
    assert = Expr(:macrocall, Symbol("@assert"), __source__, ex, msg)
    test = Expr(:macrocall, Symbol("@test"), __source__, ex)
    trycatch = :(
        try $assert
        catch e
            if e isa AssertionError
                # Display @test's output, but without erroring
                try $test catch end
            end
            # ..now we can error
            rethrow(e)
        end
    )
    # Make sure the (re)throw also points to the original source
    tryblock = trycatch.args[1]
    tryblock.args[1] = __source__  # First line of the `try` block
    return esc(trycatch)
end


# Wishlist:
# - Simplify. Don't use Test. Instead extract the variables in the
#   expression by hand, and show them.
#   (Test is too verbose: it partly repeats the expression).
#   So output will just be:
#
#       AssertionError: 0 ≤ pₑ ≤ 1
#           pₑ = 1.66666667
#       Stacktrace:
#       ..
