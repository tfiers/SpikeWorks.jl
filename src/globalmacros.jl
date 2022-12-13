
# could be a package, GlobalMacros.jl
# >:)
#
# > With thanks to Simeon for help with `@typed`,  and Giordano for the idea of `@typed`.

"""
    @constants

Rewrite variable assignments to constant assignments
(which have [performance benefits] over untyped globals).
As an example, the following:

    @constants begin
        a = 2
        b = 2.8
    end

is equivalent to

    const a = 2
    const b = 2.8

[performance benefits]: https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-untyped-global-variables
"""
macro constants(ex)
    esc(declare_all_constant(ex))
end
declare_all_constant(ex) = rewrite_assignments(ex, declare_const)

function declare_const(ex)
    @assert is_assignment(ex)
    l, r = ex.args
    # `const x,y = 1,2` is valid Julia syntax (both will be constants).
    # So we do not need to check whether `l isa Symbol`.
    return :( const $l = $r )
end

rewrite_assignments(ex, f, g = identity) =
    if     is_assignment(ex)  f(ex)
    elseif is_const_ass(ex)   g(ex)
    elseif is_block(ex)       rewrite_all_in_block(ex, e -> rewrite_assignments(e, f, g))
    else                      ex
    end

# rewrite_all_in_block(ex, f) = Expr(:block, mapany(f, ex.args)...)
# ↪ `mapany` over `map` for performance reasons: https://discourse.julialang.org/t/90818/6

function rewrite_all_in_block(ex, f)
    @assert is_block(ex)
    lines = []
    for line in ex.args
        out = f(line)
        if is_block(out)
            # No nested blocks :)
            append!(lines, out.args)
        else
            push!(lines, out)
        end
    end
    return Expr(:block, lines...)
end

is_assignment(ex) = isexpr(ex, :(=))
is_block(ex) = isexpr(ex, :block)
# We use Meta.isexpr, as `ex` may be a LineNumberNode too.

is_const_ass(ex) = isexpr(ex, :const) && is_assignment(only(ex.args))


"""
    @typed

Automatically annotate global assignments with the type of the right-hand-side.
I.e. this is a convenient way to use get the performanc benefits of [typed globals],
without having to manually annotate every variable.

As an example, the following:

    @typed begin
        a = 2
        b = 2.8
    end

is equivalent to

    a::Int = 2
    b::Float64 = 2.8

`@typed` is currently not combinable with [`@export_all`](@ref),
and destructuring (`x, y = 3, 5`) is not yet supported.

[typed globals]: https://docs.julialang.org/en/v1/manual/variables-and-scoping/#man-typed-globals
"""
macro typed(ex)
    annotate_all_assignments_with_type(ex)
end
annotate_all_assignments_with_type(ex) = rewrite_assignments(ex, annotate_with_type)

function annotate_with_type(ex)
    @assert is_assignment(ex)
    lhs, rhs = ex.args
    if lhs isa Symbol
        # ok: `x = …`
    elseif isexpr(lhs, :tuple)
        # `x, y = z`
        error("Destructuring is not supported `($ex)`")
    else
        # E.g. `f(x) = 3`
        error("Auto-typing expressions like `$(lhs)` is not supported.")
    end
    # Handle literals differently than more complex expressions.
    # See https://docs.julialang.org/en/v1/devdocs/ast/
    # I.e. we want to catch the "atoms" in the 'else' clause
    if rhs isa Expr
        # Some example right-hand sides that are `Expr`s (see ast docs above for more):
        # f(…), [1, 2], @blah …, y[1], y.a, 3im, 11111111111111111111, if …, (1,2)
        #
        # The expression on the right hand side might have side effects. We do not want to
        # execute them twice. Hence, a temporary variable, with a new unique name, scoped
        # away in a `let` block, with the real name 'escaped' using `global`.
        # Thanks to Simeon Schaub: https://discourse.julialang.org/t/90818/2
        tmp = gensym(lhs)
        return :(
            let $tmp = $rhs
                global $lhs::typeof($tmp) = $tmp
            end
        )
    else
        # Example right-hand sides that are not `Expr`s:
        # ["blah", 88, yo, :yo, Yo, 3f0, :(+)]
        #
        # The rhs probably has no side effects.
        # So, we return a simpler expression. The goal is user inspectability;
        # i.e, for simple cases, does `@macroexpand` return something scary or not.
        T = Symbol(@eval typeof($rhs))
        return :( $lhs::$T = $rhs )
    end
end


"""
    @export_all

Add an `export` statement below each assignment.
For example:

    @export_all begin
        const x = 3
        const y = 5
    end

expands to

    const x = 3
    export x

    const y = 5
    export y

Note that the above can be rewritten even more compactly using [`@constants`](@ref):

    @export_all @constants begin
        x = 3
        y = 5
    end

`@export_all` can also be used with single assignments:

    @export_all f(x) = 2x

expands to:

    f(x) = 2x
    export f

`@export_all` can currently not be used with `function` definitions.
It is also not combinable with [`@typed`](@ref).
"""
macro export_all(ex)
    add_exports_for_all(ex)
end
add_exports_for_all(ex) = rewrite_assignments(ex, add_export, add_export)

function add_export(ex)
    if is_assignment(ex)
        assignment = ex
    elseif is_const_ass(ex)
        assignment = only(ex.args)
    end
    names = get_assigned_names(assignment)
    return quote
        $ex
        export $(names...)
    end
end
# enhancement: gather all names in block, and have single export expr :)

get_assigned_names(ex) = begin
    @assert is_assignment(ex)  # I.e. not compatible with @typed, which makes a `let` block.
    lhs, _ = ex.args
    names = get_names(lhs)
    names isa Symbol ? [names] : names
end

get_names(lhs::Symbol) = lhs
get_names(lhs) =
    if isexpr(lhs, :tuple)     # x, f(z) = 2, 8
        get_names.(lhs.args)
    elseif isexpr(lhs, :call)  # f(z) = 8
        first(lhs.args)  # Cannot have this on same line as prev. Strange.
    elseif isexpr(lhs, :(::))  # x::Int = 8
        first(lhs.args)
    else
        error("Cannot export an expression like `$(lhs)`.")
    end
