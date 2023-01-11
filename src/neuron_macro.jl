# [See ../design/neuron_struct_macro.jl for an example]

macro Neuron(typename, defblock)
    esc(neuron_structs_def(typename, defblock))
end

neuron_structs_def(typename, defblock) = begin
    typename_Vars = Symbol(string(typename) * "_Vars")
    typename_Derivs = Symbol(string(typename) * "_Derivs")
    quote
        @kwdef mutable struct $typename_Vars <: NeuronVars
            $(vars(defblock)...)
        end
        @kwdef mutable struct $typename_Derivs <: NeuronVarDerivatives
            $(Dₜvars(defblock)...)
        end
        @kwdef struct $typename <: Neuron
            vars   ::$typename_Vars   = $(typename_Vars)()
            Dₜvars ::$typename_Derivs = $(typename_Derivs)()
        end
    end
end

vars(defblock) = [with_type_annotation(ex) for ex in defblock.args]

with_type_annotation(ex::LineNumberNode) = ex
with_type_annotation(ex::Expr) = begin
    lhs, rhs = ex.args
    lhs isa Symbol || return ex  # If already type-annotated, eg
    :( $lhs::typeof($rhs) = $rhs )
    # rhs will be executed twice. If side effects: too bad :)
end

Dₜvars(defblock) = [Dₜvar(ex) for ex in defblock.args]
Dₜvar(ex) = with_type_annotation(zero_time_derivative(ex))

zero_time_derivative(ex::LineNumberNode) = ex
zero_time_derivative(ex::Expr) = begin
    lhs, rhs = ex.args
    :( $lhs = zero($rhs/seconds))
end
