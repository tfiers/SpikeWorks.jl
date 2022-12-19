
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
current(c::Counter) = c.i[]

increment!(c::Counter) = (c.i[] += 1)
hasstarted(c::Counter) = (c.i[] > 0)
completed(c::Counter) = (c.i[] == c.N)
progress(c::Counter) = c.i[] / c.N

pctfmt(frac) = @sprintf("%.0f%%", 100*frac)

@humanshow(Counter)
datasummary(c::Counter) = begin
    i, N = c.i[], c.N
    (completed(c) ? "$N (complete)"
                  : "$i/$N")
end
