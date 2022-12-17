
function humanrepr(x::T) where T
    if hasmethod(show, Tuple{IO, MIME"text/plain", T})
        # For existing types, that did this the 'proper', verbose way.
        return repr(MIME("text/plain"), x)
        # hm. maybe not.¹ otoh, if we don't do it, and people wanna re-use
        # existing nice reprs from other packages, they need to type pirate
        # (the type from OtherPkg, `humanrepr` from this pkg)
        # So an alternative would be sth like
        #    `HumanRepr.use_plaintext_show(OtherPkg.Type)`
        # (which pushes to a global in HumanRepr pkg).
        #
        # ¹ why not? cause other types might eg print their typename already in the `[…]`,
        #   so that's duplicated.
    else
        # If no `show(, ::MIME"text/plain"…)` is defined, Julia falls back to plain `show`,
        # which we don't want.
        error("$humanrepr is not defined for $T")
    end
end

macro humanshow(T, f = humanrepr)
    esc(:(
        Base.show(io::IO, ::MIME"text/plain", x::$T) =
            print(io, nameof($T), " [", $f(x), "]")
    ))
    # `nameof(T)`, to not have module name
end
