
struct Counter
    N::Int
    i::RefValue{Int}

    function Counter(N, i)
        @test 0 ≤ i ≤ N
        new(N, Ref(convert(Int, i)))
    end
end
Counter(N) = Counter(N, 0)

current(c::Counter) = c.i[]
ntotal(c::Counter) = c.N

increment!(c::Counter) = (c.i[] += 1)
hasstarted(c::Counter) = (c.i[] > 0)
completed(c::Counter) = (c.i[] == c.N)
progress(c::Counter) = c.i[] / c.N

pctfmt(frac) = @sprintf("%.0f%%", 100*frac)

@humanshow(Counter)
humanrepr(c::Counter) = (completed(c) ? countstr(c.N)
                                      : countstr(c.i[], c.N))
countstr(N) = "$N (complete)"
countstr(i, N) = "$i/$N"
