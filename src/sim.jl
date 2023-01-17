


struct SystemState{N<:Neuron}
    t       ::RefValue{Float64}
    neurons ::Vector{N}
end

struct System{N}

struct Simulation{N}
    sys          ::System{N}
    state        ::SystemState{N}
    duration     ::Float64
    Δt           ::Float64
    stepcounter  ::Counter
end

completed(s::Simulation) = completed(s.stepcounter)

run!(s::Simulation) =
    while !completed(s)
        step!(s)
    end

step!(s::Simulation) = let (; state, Δt) = s
    i = increment!(s.stepcounter)
    t = (state.t[] += Δt)
    for neuron in state.neurons
        eulerstep!(neuron, Δt)
        if has_spiked(neuron, t)
            # [record t]
            on_self_spike!(neuron, t)
        end
        for var in vars_to_record(neuron)
            rec[neuron][var][i] = neuron[var]
        end
    end
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
