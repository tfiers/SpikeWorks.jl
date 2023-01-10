
# What we want:

@neuron CobaIzhNeuron_v3 begin
    v = vᵣ
    u = 0*pA
    i = 1
end
#
# ..expands to..
#
@kwdef mutable struct CobaIzhNeuron_Vars
    v ::Float64 = vᵣ
    u ::Float64 = 0*pA
    i ::Int64   = 1
end
@kwdef mutable struct CobaIzhNeuron_DₜVars
    v ::Float64 = zero(vᵣ/second)
    u ::Float64 = zero(0*pA/second)
    i ::Float64 = zero(1/second)
end
@kwdef struct CobaIzhNeuron
    vars::CobaIzhNeuron_Vars = CobaIzhNeuron_Vars()
    Dₜvars::CobaIzhNeuron_DₜVars = CobaIzhNeuron_DₜVars()
end


# Lesgo

macro neuron(name, defblock)
    esc(neuron_structs_def(name, defblock))
end

defblock = quote
    v = vᵣ
    u = 0*pA
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

Dₜvars(defblock) = [Dₜvar(ex) for ex in defblock.args]
Dₜvar(ex) = with_type_annotation(zero_time_derivative(ex))

with_type_annotation(ex::LineNumberNode) = ex
with_type_annotation(ex::Expr) = begin
    lhs, rhs = ex.args
    T = @eval typeof($rhs)
    # rhs will be executed twice. If side effects: too bad :)
    :( $lhs::$(Symbol(T)) = $rhs )
end

zero_time_derivative(ex::LineNumberNode) = ex
zero_time_derivative(ex::Expr) = begin
    lhs, rhs = ex.args
    :( $lhs = zero($rhs/second))
end


# (works beautifully)

code_warntype() do
    CobaIzhNeuron_v3().vars.v
end
# (nicely infers Float64 :))

# (could add auto-versioning for user structs :)
#  (i.e. see if already defined, and if so, append "_v2" (etc)))
