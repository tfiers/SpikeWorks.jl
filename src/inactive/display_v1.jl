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
