
"""
    poisson_spikes(r, T)

Generate Poisson spiketimes with firing rate `r` on the time interval `[0, T]`.

More precisely, simulate a Poisson process by drawing inter-spike-intervals from an
Exponential distribution with rate parameter `r`, accumulating them until `T` is reached.
The number of spikes `N` in `[0, T]` will be Poisson-distributed, with mean = `rT`.

The output is a length-`N` (i.e. variable-length) vector of spike times.
"""
function poisson_spikes(r, T)
    # As we cannot predict how many spikes we will have generated when reaching `T`, we
    # allocate an array long enough to very likely fit all of them, and trim off the unused
    # end on return.¹
    N_distr = Poisson(r*T)
    max_N = cquantile(N_distr, 1E-14)       # `complementary quantile`²
    spikes = Vector{Float64}(undef, max_N)
    ISI_distr = Exponential(inv(r))         # Parametrized by scale = 1 / rate
    N = 0
    t = rand(ISI_distr)
    while t ≤ T
        N += 1
        spikes[N] = t
        t += rand(ISI_distr)
    end
    resize!(spikes, N)
end
# ¹ For an idea of the expected overhead of this: for r = 100 Hz and T = 10 minutes, the
#   expected N is 60000, and at P(N > max_N) = 1E-14, max_N is 61855.
# ² If the provided probability here is smaller than ~1E15, we get an error (`Inf`):
#   https://github.com/JuliaStats/Rmath-julia/blob/master/src/qpois.c#L86


poisson_SpikeTrain(r,T) = SpikeTrain(poisson_spikes(r,T), T; checksorted = false)
