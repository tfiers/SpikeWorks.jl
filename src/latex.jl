
using Latexify
using LaTeXStrings
using PartialFunctions
using Chain


function show_eqs(m::ParsedDiffeqs; lhsfrac = true)
    eqs = map(prep_for_align $ (; lhsfrac), m.original_eqs)
    lines = ["\\begin{align}" eqs... "\\end{align}"]
    LaTeXString(join(lines, " \n"))
end

prep_for_align(eq; lhsfrac) = @chain begin
    latexify(eq).s
    prettify_eq(_; lhsfrac)
    strip(_, '$')
    replace(_, " = " => " &= ")
    _ * "\\\\"
end

prettify_eq(x::LaTeXString; lhsfrac) = x.s |> prettify_eq |> LaTeXString
prettify_eq(s::String; lhsfrac) = begin
    # - Replace right-hand-side fractions with plain divisions
    # - No \cdots
    # - Upright differentials
    # - more space around =
    lhs, rhs = split(s, " = ")
    rhs = replace_fracs(rhs)
    rhs = replace(rhs, " \\cdot " => " ")
    lhs = replace(lhs, "\\frac{d" => "\\frac{\\mathrm{d}")
    lhs = replace(lhs, "{dt}" => "{\\mathrm{d}t}")
    if lhsfrac == false
        lhs = replace_fracs(lhs)
    end
    lhs * " = \\ " * rhs
end

function replace_fracs(s)
    while true
        fr = findfirst("\\frac", s)
        if isnothing(fr)
            break
        end
        c1 = find_closing_bracket(s, fr.stop + 1)
        c2 = find_closing_bracket(s, c1 + 1)
        pre = s[1:fr.start-1]
        num = s[fr.stop+1:c1]
        denum = s[c1+1:c2]
        post = s[c2+1:end]
        # Wrap expression in brackets if complex
        wrap(ex) = (' ' in ex) ? "\\left( $ex \\right)" : ex
        # The `\middle/` syntax makes the division sign scale.
        # The `.` of the accompanying `\left.` and `\right.` are not shown.
        l, div, r = "\\left. ", "\\,\\middle/ \\,", "\\right. "
        s = pre * l * wrap(num) * div * wrap(denum) * r * post
    end
    s
end

function find_closing_bracket(s, i)
    @test s[i] == '{'
    opened_brackets = 1
    while opened_brackets > 0
        i += 1
        if s[i] == '{'
            opened_brackets += 1
        elseif s[i] == '}'
            opened_brackets -= 1
        end
    end
    i
end
