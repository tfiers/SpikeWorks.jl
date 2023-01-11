
struct SystemState{N<:Neuron}
    t       ::RefValue{Float64}
    neurons ::Vector{N}
end

struct Simulation{N}
    sys          ::System
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

step!(s::Simulation) = begin
    i = increment!(s.stepcounter)
    (; state, Δt) = s
    t = (state.t[] += Δt)
    for n in state.neurons
        eulerstep!(n, Δt)
        if has_spiked(n)
            # [record t]
            on_self_spike!(n)
        end
        for var in to_record(n)
            recording[n][var][i] = vars(n)[var]
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
