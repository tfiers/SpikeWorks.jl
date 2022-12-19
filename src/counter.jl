
struct Counter
    N::Int
    i::RefValue{Int}

    function Counter(N, i)
        @check 0 ≤ i ≤ N
        new(N, Ref(convert(Int, i)))
    end
end
Counter(N) = Counter(N, 0)

ntotal(c::Counter) = c.N
state(c::Counter) = (
    i = c.i[],
    N = c.N,
)
unsafe_current(c::Counter) = c.i[]
current(c::Counter) = begin
    @check 0 < c.i[] ≤ c.N
    c.i[]
end
unsafe_increment!(c::Counter) = (c.i[] += 1)
increment!(c::Counter) = begin
    @check c.i[] < c.N
    c.i[] += 1
end

# When the above bounds-checking safeguards turn out to take signifant
# time (as seen in profiling), the `unsafe` methods may be used.
# (The checks are in place to avoid out-of-bounds memory access when the
#  counter is used to index @inbounds into a vector).

hasstarted(c::Counter) = (c.i[] > 0)
completed(c::Counter) = (c.i[] == c.N)
progress(c::Counter) = c.i[] / c.N

pctfmt(frac) = @sprintf("%.0f%%", 100*frac)

@humanshow(Counter)
datasummary(c::Counter) = begin
    i, N = state(c)
    (completed(c) ? "$N (complete)"
                  : "$i/$N")
end
