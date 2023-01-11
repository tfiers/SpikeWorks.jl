# [See ../design/neuron_struct_macro.jl for an example]

macro NeuronModel(typename, defblock)
    esc(neuron_structs_def(typename, defblock))
end

neuron_structs_def(typename, defblock) = begin
    typename_Vars = Symbol(string(typename) * "_Vars")
    typename_DₜVars = Symbol(string(typename) * "_DₜVars")
    quote
        @kwdef mutable struct $typename_Vars <: NeuronModel_Vars
            $(vars(defblock)...)
        end
        @kwdef mutable struct $typename_DₜVars <: NeuronModel_DₜVars
            $(Dₜvars(defblock)...)
        end
        @kwdef struct $typename <: NeuronModel
            vars   ::$typename_Vars   = $(typename_Vars)()
            Dₜvars ::$typename_DₜVars = $(typename_DₜVars)()
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
