
struct System
    neurons ::
end

struct SystemState{N<:NeuronState,D}
    t      ::RefValue{Float64}
    vars   ::Vector{N}
    Dₜvars ::Vector{D}
end

struct Simulation
    sys          ::System
    state        ::SystemState
    duration     ::Float64
    Δt           ::Float64
    stepcounter  ::Counter
end

completed(s::Simulation) = completed(s.stepcounter)

run!(s::Simulation) = (
    while !completed(s)
        step!(s)
    end; s
)

step!(s::Simulation) = begin
    i = increment!(s.stepcounter)
    (; state, Δt) = s
    t = (state.t[] += Δt)
    neurons = state.neurons
    for i in eachindex(neurons)
        (; vars, Dₜvars) = neuron
        update!(Dₜvars, vars)
        for (v, Dₜv) in zip(vars, Dₜvars)

end

struct Recording
end

struct SimResult
    sim::Simulation
    rec::Recording
end

simulate() = begin
    s = Simulation()
    run!(s)
    return SimResult(s)
end
