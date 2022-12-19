
struct NamedVector{T,N} <: AbstractVector{T}
    names::NTuple{N,Symbol}
    data::Vector{T}

    function NamedVector{T}(names, data) where T
        # @assert length(names) == length(data)
        @check length(names) == length(data)
        names = tuple(names...)
        vec = collect(T, data)  # Errors if conversion is not possible ✔
        N = length(vec)
        new{T,N}(names, vec)
    end
end

NamedVector(names, data) = begin
    # Find a concrete type that can represent all elements.
    # I.e. behave as `vect` (which is what is called for eg `[3, 0.3]`)
    T = Base.promote_typeof(data...)
    NamedVector{T}(names, data)
end

names(x::NamedVector) = getfield(x, :names)
data(x::NamedVector) = getfield(x, :data)

# Alternative accesors for the same fields (more common / expected names)
Base.keys(x::NamedVector) = names(x)
Base.values(x::NamedVector) = data(x)

# Construction from, and conversion to NamedTuple
NamedVector(x::NamedTuple) = NamedVector(keys(x), values(x))
NamedTuple(x::NamedVector) = NamedTuple{names(x)}(tuple(data(x)...))

# Keyword construction (via NamedTuple constructor)
NamedVector(; kw...) = NamedVector((; kw...))

# Allow providing the type to convert to explicitly
NamedVector{T}(x::NamedTuple) where T = NamedVector{T}(keys(x), values(x))
NamedVector{T}(; kw...) where T = NamedVector{T}((; kw...))

# Shorthand for interactive use (less typing in the REPL)
const NVec = NamedVector

# [Revise]
NamedVector = NamedVector

# Array interface
Base.size(x::NamedVector) = size(data(x))
Base.IndexStyle(::NamedVector) = IndexLinear
Base.getindex(x::NamedVector, i::Int) = data(x)[i]
Base.setindex!(x::NamedVector, v, i::Int) = (data(x)[i] = v)
# `eltype` is known through subtyping `AbstractArray{T,1}`

# Conversion interface
# This is useful for e.g. composite types with a `::NamedVector` field.
# When calling their constructor with a NamedTuple, it will auto-convert.
Base.convert(::Type{NamedVector}, x::NamedTuple) = NamedVector(x)
Base.convert(::Type{NamedTuple}, x::NamedVector) = NamedTuple(x)

# Named access (why we're doing all this)
Base.propertynames(x::NamedVector) = keys(x)
Base.getproperty(x::NamedVector{T}, name::Symbol) where T = _get(x, name)::T

function Base.getproperty(x::NamedVector{T}, name::Symbol) where T
    i = indexof(x, name)
    return x.data[i]::T
end
indexof(x::NamedVector, name::Symbol) = findfirst(==(name), names(x))
# ↪ If necessary, this could mayb be spedup with a new cache field:
#   a dict, or a namedtuple(:v=>1, :u=>2, …) (would mean adding names to type)
#   (There is no special `index(arr, el)` method; that's `findfirst`).
#       Ye, such an 'index' namedtuple might be a good idea:
#       `@edit nt.a` goes to (in julia/base/Base.jl):
#
#          getproperty(x, f::Symbol) = (@inline; getfield(x, f))
#
#       ..which looks very efficient.
#       (we'd do: `return x.data[x.indices[:name])`)
#       (that syntax goes to (same same):
#           getindex(t::NamedTuple, i::Symbol) = getfield(t, i)
#       )

# julia> show(Named)
# NamedVector
Base.show(io::IO, x::NamedVector) = print(io, nameof(typeof(x)), NamedTuple(x))
Base.show(io::IO, m::MIME"text/plain", x::NamedVector) = begin
    # We Vaguely recapitulate `show(io, m, ::AbstractArray)`
    # (from arrayshow.jl in julia/base) here.
    # Without `Base.summary` though, as the elcount is already in the type.
    println(io, typeof(x), ":")
    io = IOContext(io, :typeinfo => eltype(x))
    items = [NamedElement(n,v) for (n,v) in zip(names(x), values(x))]
    Base.print_array(io, items)
end
# For use by julia's `print_array`
struct NamedElement{T}
    name::Symbol
    val::T
end
Base.show(io::IO, el::NamedElement) = print(io, el.name, " = ", el.val)


# [commentdump]

# The names-in-type way:
#
#   struct NamedVector{names,T}
#       data::Vector{T}
#
#       function NamedVector{names}(data) where names
#           @test length(names) = length(data)
#           new{names}(data)
#       end
#   end
#   NamedVector(x::NamedTuple{n}) where n = NamedVector{n}(collect(x))
#
# But why would we want em in type ey.
# They're all same type :)


# function NamedVector(names, data)
#     vec = collect(data)
#     T = eltype(vec)
#     if !isempty(vec)
#         datatypes = [typeof(el) for el in data]
#         if all(isconcretetype, datatypes) && !isconcretetype(T)
#             @warn """
#             Values could not be promoted to the same concrete type.
#             This is likely to hurt performance¹\n
#                  Values (concrete): $data
#             Common type (abstract): $T\n
#             ¹To understand why, see e.g: https://blog.sintef.com/industry-en/writing-type-stable-julia-code
#             """
#         end
#     end
#     return NamedVector{T}(names, vec)
# end

# We don't include fields in the properties.
# The inferred type for getprop is then `Union{T, NTuple{Symbol, N}, Vector{T}}`,
# which might be too big; it's red in @code_warntype.
#
#   Base.propertynames(x::NamedVector) = [fieldnames(NamedVector); names(x)]
#   Base.getproperty(x::V, name::Symbol) where V<:NamedVector{T} where T = (
#       name in fieldnames(V) ? getfield(x, name)
#                             : x.data[indexof(x, name)]::T
#   )
