# [See ../design/neuron_struct_macro.jl for an example]

macro neuron(name, defblock)
    esc(neuron_structs_def(name, defblock))
end

neuron_structs_def(name, defblock) = begin
    TypeName = name
    TypeName_Vars = Symbol(string(name) * "_Vars")
    TypeName_DₜVars = Symbol(string(name) * "_DₜVars")
    quote
        @kwdef mutable struct $TypeName_Vars
            $(vars(defblock)...)
        end
        @kwdef mutable struct $TypeName_DₜVars
            $(Dₜvars(defblock)...)
        end
        @kwdef struct $TypeName
            vars   ::$TypeName_Vars   = $(TypeName_Vars)()
            Dₜvars ::$TypeName_DₜVars = $(TypeName_DₜVars)()
        end
    end
end

vars(defblock) = [with_type_annotation(ex) for ex in defblock.args]

with_type_annotation(ex::LineNumberNode) = ex
with_type_annotation(ex::Expr) = begin
    lhs, rhs = ex.args
    T = @eval typeof($rhs)
    # rhs will be executed twice. If side effects: too bad :)
    :( $lhs::$(Symbol(T)) = $rhs )
end

Dₜvars(defblock) = [Dₜvar(ex) for ex in defblock.args]
Dₜvar(ex) = with_type_annotation(zero_time_derivative(ex))

zero_time_derivative(ex::LineNumberNode) = ex
zero_time_derivative(ex::Expr) = begin
    lhs, rhs = ex.args
    :( $lhs = zero($rhs/second))
end
