
"""
    EIMix

A division between excitatory (E) and inhibitory neurons (I).

Constructed as `EIMix(N, x)`, where `x` is interpreted as:
- the `E:I` proportion if a `Rational`;
- the number of excitatory neurons, `Nₑ` if an `Integer`;
- and the fraction of excitatory neurons, `pₑ` if any other `Real`.

## Examples
```
julia> m = EIMix(Nₑ = 40, Nᵢ = 10)
EIMix of 50 neurons
- 40 excitatory (80%)
- 10 inhibitory (20%)
- 4:1 EI-ratio

julia> EIMix(50, 4//5) == m
true
```
"""
struct EIMix
    N::Int
    Nₑ::Int
    Nᵢ::Int
    EtoI::Rational
    pₑ::Float64
    pᵢ::Float64

    function EIMix(N::Integer, Nₑ::Integer)
        @check N ≥ Nₑ ≥ 0
        Nᵢ = N - Nₑ
        EtoI = Nₑ // Nᵢ
        pₑ = Nₑ / N
        pᵢ = Nᵢ / N
        new(N, Nₑ, Nᵢ, EtoI, pₑ, pᵢ)
    end
end

function EIMix(N::Int, EtoI::Rational)
    E,I = (numerator(EtoI), denominator(EtoI))
    pₑ = E / (E+I)  # == 1 - 1/(1+EtoI)
    EIMix(N, pₑ)
end

function EIMix(N::Integer, pₑ)
    @check 0 ≤ pₑ ≤ 1
    E = pₑ * N
    Nₑ = round(Int, E)
    m = EIMix(N, Nₑ)
    if !isinteger(E)
        @warn """
        The provided pₑ = $pₑ
        does not divide N = $N into integer parts.
        (pₑ * N = $E).
        pₑ was changed to $(m.pₑ)
        """
    end
    m
end

EIMix(; kw...) = @error "Construction by keyword not yet supported"


Base.show(io::IO, ::MIME"text/plain", m::EIMix) = begin
    E,I = (numerator(m.EtoI), denominator(m.EtoI))
    println(io, EIMix, " of $(m.N) neurons")
    println(io, "- $(m.Nₑ) excitatory ($(pctfmt(m.pₑ)))")
    println(io, "- $(m.Nᵢ) inhibitory ($(pctfmt(m.pᵢ)))")
    println(io, "- $E:$I EI-ratio")
end

# ~~ kwarg construction `~~

# To use the keyword argument constructor, specify either:
# - two arguments from (`N`, `Nₑ`, `Nᵢ`) (as integers);
# - or one from that list, and one from (`pₑ`, `pᵢ`, `EtoI`)
#   (as an integer and a real).

# Note that you can enter the subscripts as e.g. `N\\_e<tab>` → `Nₑ`.\\
# You can also use aliases like `Ne`, `Ni`, and `pE` instead.


# normalize(name::Symbol) = Symbol(normalize(string(name)))
# normalize(name::String) =

# function EIMix(; kw...)
#     counts = [:N, :Nₑ, :Nᵢ]
#     fracs = [:EtoI, :pₑ, :pᵢ]
#     @check any(in keys(kw), )
# end
