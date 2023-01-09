
"""
    EIMix

A division between excitatory (E) and inhibitory neurons (I).

Constructed as `EIMix(N, x)`, where `N` is the total number of neurons,
and `x` is interpreted as:
- the `E:I` ratio, if a `Rational`;
- the number of excitatory neurons, `Nₑ`, if an `Integer`;
- and the fraction of neurons that is excitatory, `pₑ`, otherwise.
"""
struct EIMix
    N::Int
    Nₑ::Int
    Nᵢ::Int
    pₑ::Float64
    pᵢ::Float64
    EIratio::Rational{Int}

    function EIMix(N::Integer; Nₑ::Integer)
        @check N ≥ Nₑ ≥ 0
        Nᵢ = N - Nₑ
        pₑ = Nₑ / N
        pᵢ = Nᵢ / N
        EIratio = Nₑ // Nᵢ
        new(N, Nₑ, Nᵢ, pₑ, pᵢ, EIratio)
    end
end

groupsizes(m::EIMix) = (; m.Nₑ, m.Nᵢ)

function EIMix(N::Integer, pₑ)
    @check 0 ≤ pₑ ≤ 1
    E = pₑ * N
    Nₑ = round(Int, E)
    m = EIMix(N; Nₑ)
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

EIMix(N::Int, EIratio::Rational) = EIMix(N, pₑ(EIratio))

"""Proportion excitatory"""
pₑ(EIratio::Rational) = begin
    E = numerator(EIratio)
    I = denominator(EIratio)
    return E / (E+I)
end
pₑ(EIratio) = 1 - 1/(1+EIratio)  # More general formula (unused here)

EIMix(; kw...) = @error "Construction by keyword not yet supported"

Base.show(io::IO, ::MIME"text/plain", m::EIMix) = begin
    (; N, Nₑ, Nᵢ, pₑ, pᵢ, EIratio) = m
    E = numerator(EIratio)
    I = denominator(EIratio)
    println(io, "$EIMix of $N neurons")
    println(io, "- $Nₑ excitatory ($(pctfmt(pₑ)))")
    println(io, "- $Nᵢ inhibitory ($(pctfmt(pᵢ)))")
    println(io, "- $E:$I EI-ratio")
end



# ~~ kwarg construction ~~

# To use the keyword argument constructor, specify either:
# - two arguments from (`N`, `Nₑ`, `Nᵢ`) (as integers);
# - or one from that list, and one from (`pₑ`, `pᵢ`, `EIratio`)
#   (as an integer and a real).

# Note that you can enter the subscripts as e.g. `N\\_e<tab>` → `Nₑ`.\\
# You can also use aliases like `Ne`, `Ni`, and `pE` instead.


# normalize(name::Symbol) = Symbol(normalize(string(name)))
# normalize(name::String) =

# function EIMix(; kw...)
#     counts = [:N, :Nₑ, :Nᵢ]
#     fracs = [:EIratio, :pₑ, :pᵢ]
#     @check any(in keys(kw), )
# end


# ## Examples
# ```
# julia> m = EIMix(Nₑ = 40, Nᵢ = 10)
# EIMix of 50 neurons
# - 40 excitatory (80%)
# - 10 inhibitory (20%)
# - 4:1 EI-ratio

# julia> EIMix(50, 4//5) == m
# true
# ```
