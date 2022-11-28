
"""
    LogNormal(; median, g, unit = oneunit(median))

Alternative parametrization of the log-normal distribution, using the real median ``m`` and
the _geometric standard deviation_, ``g``. The relationship with the standard
parametrization – which uses the mean ``μ`` and the standard deviation ``σ`` of
the log-transformed, unitless normal distribution – is as folows:
- ``m = e^μ · u``
- ``g = e^σ``

As a consequence of this relationship, ~two-thirds of the distribution lies within
``[m/g, m·g]``, and ~95% lies within ``[m/g², m·g²]``.

On the default unit ``u`` of `oneunit(median)`: if `median = 5mV`, then `unit = 1mV`, and if
`median = 4`, then `unit = 1`.

Unfortunately, Distributions.jl has no unit support ([yet][1]).\\
To obtain correct results from this distribution, add the same `unit` manually to the
appropriate methods:
- `rand(d) * mV`
- `mean(d) * mV`\\
etc.

[1]: https://github.com/JuliaStats/Distributions.jl/issues/1413
"""
LogNormal(; median, g, unit = oneunit(median)) = begin
    μ = log(median/unit)
    σ = log(g)
    Distributions.LogNormal(μ, σ)
end

# If you want to add other parametrizations:
# LogNormal(; kw...), and then a switch/match stmt.
