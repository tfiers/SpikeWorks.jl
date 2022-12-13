
using Firework
using Test
using MacroTools: striplines

≅(x, y) = striplines(x) == striplines(y)

@testset "globalmacros.jl" begin

    ex = quote
        a = 2
        b = 2.8
    end

    @test Firework.declare_all_constant(ex) ≅ quote
        const a = 2
        const b = 2.8
    end

    @test Firework.annotate_all_assignments_with_type(ex) ≅ quote
        a::Int64 = 2
        b::Float64 = 2.8
    end

    @test Firework.add_exports_for_all(ex) ≅ quote
        a = 2
        export a
        b = 2.8
        export b
    end

    const_ex = Firework.declare_all_constant(ex)
    @test Firework.add_exports_for_all(const_ex) ≅ quote
        const a = 2
        export a
        const b = 2.8
        export b
    end

    # The following combination is not supported according to our docs;
    # but it actually works, for these simple assignments.
    typed_ex = Firework.annotate_all_assignments_with_type(ex)
    @test Firework.add_exports_for_all(typed_ex) ≅ quote
        a::Int64 = 2
        export a
        b::Float64 = 2.8
        export b
    end


    # Test: a = b = 3 :)
end
