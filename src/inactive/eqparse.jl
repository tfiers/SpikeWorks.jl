
using Base: @kwdef
using StructArrays
using MacroTools: striplines, unblock
using Base.Iterators: flatten
using DataStructures: SortedSet
using Test  # We use @test instead of @assert as it gives a more useful error message


# `kwdef`: for more readable constructor calls (see below).
@kwdef struct Var
    name       ::Symbol
    has_diffeq ::Bool
end

struct ParsedDiffeqs
    original_eqs   ::Vector{Expr}
    generated_func ::Expr
    f!             ::Function
    rhss           ::Vector{Expr}
    vars           ::StructVector{Var}
    params         ::Vector{Symbol}
end

Base.show(io::IO, x::Var) = print(io, x.name)
Base.show(io::IO, m::ParsedDiffeqs) = begin
    println(io, typeof(m))
    println(io, " with variables {", join(m.vars, ", "), "}")
    println(io, " and parameters {", join(m.params, ", "), "}")
end


macro eqs(ex)
    out = nothing  # `try` is a new scope (unlike `if`). So local vars not visible outside.
    try
        out = process_eqs!(ex)
    catch e
        throw(e)
        # throw(ArgumentError("Could not parse the given equations."))
        # Seems like a `throw(custom_err)` does _not_ preseve error stack?
    end
    f, original_eqs, rhss, vars, params = out
    qg = Expr(:quote, striplines(f))  # Trick to return an expression from a macro
    return :( ParsedDiffeqs($original_eqs, $qg, $f, $rhss, $vars, $params) )
end

function process_eqs!(block::Expr)
    @test block.head == :block
    line_nrs::Vector{LineNumberNode} = block.args[1:2:end]  # Info on source file & loc
    eqs     ::Vector{Expr}           = block.args[2:2:end]
    # Copy and recursively remove the `LineNumberNode`s from children
    eqs = deepcopy(eqs) |> striplines
    vars, params = get_names(eqs)
    # `dx/dt = …` makes the rhs a block, so `unblock`
    rhss = [unblock(line.args[2]) for line in eqs]
    # Change the left-hand side of each line, from `dx/dt = …` to `diff.x = …`
    assignments = Expr[]
    for (var, rhs) in zip(vars, rhss)
        buffer = (var.has_diffeq) ? :diff : :vars
        push!(assignments, :( $(buffer).$(var.name) = $(rhs) ))
    end
    lines = collect(flatten(zip(line_nrs, assignments)))
    # Unpack variables and parameterss at the top of the function
    insert!(lines, 1, :( (; $(vars.name...),) = vars ))
    insert!(lines, 2, :( (; $(params...),)    = params ))
    # ----NOTE this is broken atm:
    #     1. no anonymous funcs please (at least not without `let`)
    #     2. changing `@unpack` to `(; ,)` broke sth
    #     3. model funcs need diff signature now.
    # Make an anonymous function
    f! = :( (diff, vars, params) -> $(lines...) )
    return f!, eqs, rhss, vars, params
end

function get_names(eqs::Vector{Expr})
    names = SortedSet{Symbol}()
    vars = StructVector{Var}(undef, 0)  # They didn't implement `SV{T}()` syntax.
    for eq in eqs
        @test eq.head == :(=)
        lhs, rhs = eq.args
        push!(vars, parse_lhs_var(lhs))
        record_names(unblock(rhs), names)
    end
    params = [n for n in names if n ∉ vars.name]
    return vars, params
end

parse_lhs_var(lhs::Symbol) = begin       # I_syn = …
    Var(name = lhs, has_diffeq = false)
end
parse_lhs_var(lhs::Expr) = begin
    @test lhs.head == :call
    f, dx, dt = lhs.args
    @test f == :/
    @test dt == :dt
    if dx isa Symbol                     # dx/dt = …
        x = string(dx)[2:end] |> Symbol
    else                                 # d(g_syn)/dt = …
        @test dx.head == :call
        f, arg = dx.args
        @test f == :d
        x = arg
    end
    Var(name = x, has_diffeq = true)
end

record_names(x::Expr, out) = begin
    @test x.head == :call
    f, args... = x.args
    for e in args
        record_names(e,out)
    end
end
record_names(x::Symbol, out) = push!(out, x)

# For numeric literals:
record_names(x, out) = nothing
