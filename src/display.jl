
"""
    datasummary(x)

A one-line, human-readable string representation of the data in `x`.

To implement this function for a new type, summarize the _contents_ of
the object (do not include the type).

See also [`show_datasummary`](@ref), which you might want to implement
instead.
"""
function datasummary end

"""
    show_datasummary([io::IO], x)

Write a one-line, human-readable summary of the data in `x` to `io`.

If `io` is not given, print to `stdout`.

Instead of implementing [`datasummary`](@ref), you could implement this
method instead. The output string does then not have to be constructed
and printed in one go. See [the docs](below) for why that is useful.
"""
function show_datasummary end

show_datasummary(x) = show_datasummary(stdout, x)

function _show_datasummary(io::IO, x; wrap = false)
    wrap && print(io, "(")
    if applicable(show_datasummary, io, x)
        show_datasummary(io, x)
    elseif applicable(datasummary, x)
        print(io, datasummary(x))
    else
        show_default_datasummary(io, x)
    end
    wrap && print(io, ")")
end

function show_default_datasummary(io::IO, x)
    # Fallback for when typeof(x) does not have any 'datasummary'
    # methods implemented.
    props = propertynames(x)
    for prop in props
        print(io, faded("$prop: "))
        val = getproperty(x, prop)
        ((nfields(val) > 0) ? _show_datasummary(io, val; wrap = true)
                            : print_short(io, val))
        ((prop == last(props)) ? (return)
                               : print(io, ", "))
    end
end

default_datasummary(x) = sprint(show_default_datasummary, x)

"""
    print_short([io::IO], x)

Print `x` in the shortest way possible using only base Julia functionality.
"""
print_short(x) = print_short(stdout, x)
print_short(io::IO, x) = print(shortcontext(io), x)
# ↪ We don't use `show(…, MIME("text/plain"), x)`, as that prints lists
#   multiline, instead of inline.
shortcontext(io::IO) = IOContext(io, :compact => true, :limit => true)

humanshow(x) = humanshow(stdout, x)
humanshow(io::IO, x) = begin
    print_type(io, x)
    println()
    if has_datasummary(x)
        print(io, faded("Summary: "), )
        _show_datasummary(io, x)
        println()
    end
    println(io, faded("Properties: "))
    names = propertynames(x)
    maxlen = maximum(s -> length(string(s)), names)
    padlen = 2 + maxlen
    for name in names
        print(io, (lpad(name, padlen)), ": ")
        val = getproperty(x, name)
        # w = PrintWrapper(io; indent = padlen + 2)
        # ↪ Too buggy still
        w = io
        ((nfields(val) > 0) ? _show_datasummary(w, val)
                            : print_short(w, val))
        println(io)
    end
end

# Aka LINE-BREAKER-6000 (wraps text printed to it)
struct PrintWrapper{S<:IO} <: IO
    io::S
    maxcol::Float64
    indent::Int
    col::RefValue{Int}
end
function PrintWrapper(
    io::IO;
    maxcol = 0.5,  # As a fraction of termwidth
    indent = 0,
    startcol = indent,
)
    @test 0 ≤ maxcol < 1
    PrintWrapper(io, maxcol, indent, Ref(startcol))
end
Base.print(w::PrintWrapper, args...) = _printw(w, args...)
Base.print(ct::IOContext{<:PrintWrapper}, args...) = begin
    # Unwrap our io from the 'context'..
    w = ct.io
    # ..and pass the wrapping to the final `io`
    io = IOContext(w.io, ct)
    _printw(w, args...; io)
end
function _printw(w::PrintWrapper, args...; io = w.io)
    termwidth = displaysize(w.io)[2]
    maxcol = round(Int, w.maxcol * termwidth)
    indent = ' '^w.indent
    printcounted(word) = begin
        print(io, word)
        w.col[] += length(word)
    end
    breakk() = begin  # `break` is keyword hah
        print(io, '\n')
        w.col[] = 0
    end
    for arg in args
        str = sprint(show, arg)
        words = split(str, ' ')
        # ↪ Do not use default delimiter (`isspace`),
        #   so as to keep newlines and the like intact.
        for word in words
            if w.col[] + length(word) > maxcol
                breakk()
                printcounted(indent)
            end
            printcounted(word)
            (word == last(words)) || printcounted(' ')
        end
    end
end
const SString = Union{String, SubString{String}}
Base.print(w::PrintWrapper, s::SString) = _printw(w, s)
# ↪ Fighting with `print(::IO, ::SString)` over precedence.
#   To fix "MethodError: print(::PrintWrapper, ::String) is ambiguous".
#   `::AbstractString` does not win btw.


const faded = Crayon(foreground = :dark_gray)
const blue = Crayon(foreground = :light_blue)

has_datasummary(x::T) where T =
    (hasmethod(datasummary, Tuple{T}) ||
     hasmethod(show_datasummary, Tuple{IO, T}))

print_type(io::IO, x; maxdepth = Inf) = print_type(io, typeof(x), maxdepth)
print_type(io::IO, T::Type, maxdepth, depth = 0) = begin
    print(io, nameof(T))
    nparams = length(T.parameters)
    if nparams > 0
        (depth == maxdepth) && (print(io, "…"); return)
        (depth == 0) && print(io, faded)
        print(io, "{")
        for (i, p) in enumerate(T.parameters)
            ((p isa Type) ? print_type(io, p, maxdepth, depth + 1)
                          : print(io, p))
            (i < nparams) && print(io, ", ")
        end
        print(io, "}")
        (depth == 0) && print(Crayon(reset = true))
    end
end
# Not handled: typealiases
# A start:
# `keep,applied1 = Base.make_typealiases(typeof(sim.state.neuron.vars))`


macro humanshow(T, f = humanshow)
    esc(:(Base.show(io::IO, ::MIME"text/plain", x::$T) = $f(x)))
end


# ComponentArrays types are so long (it's cause they can take whatever
# data structures. But we only use Vector{Float64}). So let's override
# `show` for our specific type alias. 🦜🏴‍☠️
#
const CVec{Ax} = ComponentVector{Float64, Vector{Float64}, Ax}
#
Base.show(io::IO, ::Type{CVec{Ax}}) where Ax =  # 🦜🏴‍☠️
    print(io, "CVec{", varnames(Ax) ,"}")
#
varnames(::Type{Tuple{ComponentArrays.Axis{nt}}}) where nt = keys(nt)




# ~~ 'the docs' ~~

# On `datasummary` vs `show_datasummary`:
#
# [..] As an illustration of why that is useful,
# consider these alternative implementations for a fictitious data type:
#
#     datasummary(w::FelineWorld) = "\$(w.ncats) cats, \$(nmice(w)) mice"
#
# The corresponding `show_datasummary` version would be

#     show_datasummary(io::IO, w::FelineWorld) =
#         print(io, w.ncats, " cats, ", nmice(w), " mice")
#
# The former, `datasummary` version is shorter and arguably clearer.
# However, imagine that '`nmice(x)`' is slow, or would error. We will
# have still printed something useful before that with
# `show_datasummary` (not so with the alternative)¹.
#
# [¹]: A wish (not now): a macro (probably f"string {blah} ok" :))
#      that does this for you (i.e. `print("string ", blah, " ok")`.
#      Yep, should work: `macro f_str(s)`. Doesn't need to return a
#      string either, can do / return w/e.
#         fStrings.jl :p
#      |
#      ↪ This would need syntax highlighting support. vs code ext :)
#           ↪ a faster way w/o extension / PR to julia-vscode:
#               @f"blah $(this+3) works already :)"
#               f"(this {does * not}, neither $(this) )"


# ~~ darling dump ~~

# a todo wish: print types yes (grayed); but not too deep.

# function show_datasummary(io::IO, f::SpikeFeed)
#     i = current(f.counter)
#     N = ntotal(f.counter)
#     ((i == N) ? print(io, "all ", N, " spikes processed")
#               : print(io, i, "/", N " spikes processed"))
# end
# datasummary(f::SpikeFeed) = begin
#     i = current(f.counter)
#     N = ntotal(f.counter)
#     if (i == N)  "all $N spikes processed"
#     else         "$i/$N spikes processed" end
# end


# ↪ `join(io, …, ", ")` with a generator is not so easy


# We do not do this in the real function, as then `applicable` (and
# `hasmethod`) would return `true` for `show_datasummary`.
