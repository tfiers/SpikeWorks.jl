# Sketch for decoupled:

# Simulated variables
struct SimulatedVariables{T,V<:AbstractVector{T}}
    x ::V
    ẋ ::V
end

mutable struct StepInfo
    i ::Int
    N ::Int
end

struct SimRecording{T}
    v      ::Vector{T}
    spikes ::Vector{T}
end

struct SimState{T,V,P}
    params::P
    Δt::T
    step::StepInfo
    vars::SimulatedVariables{T,V}
    rec::SimRecording{T}
end
