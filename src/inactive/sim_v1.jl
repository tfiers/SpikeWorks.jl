
"""
    SpikingInput(s, f!)

- `s`:  Vector of spiketimes.
- `f!`: Function of `(vars; params...)`, called when a spike of `s` arrives at the target
        neuron.
"""
struct SpikingInput
    sf::SpikeFeed
    f!::Function
end
SpikingInput(spikes::AbstractVector, f!) = SpikingInput(SpikeFeed(spikes), f!)
SpikingInput = SpikingInput

count_new_spikes!(i::SpikingInput, t) = advance_to!(i.sf, t)
Base.length(::SpikingInput) = 1  # To work as part of a ComponentArray.
Base.show(io::IO, si::SpikingInput) = begin
    print(io, SpikingInput, " with ", si.sf, " and ", si.f!)
end


struct Nto1Model{F<:Function, G<:Function, H<:Function, I<:AbstractVector{<:SpikingInput}}
    eval_diffeqs!  ::F
    has_spiked     ::G
    on_self_spike! ::H
    inputs         ::I
end
Nto1Model(pd::ParsedDiffeqs, args...) = Nto1Model(pd.f!, args...)
Nto1Model = Nto1Model

Base.show(io::IO, m::Nto1Model) = begin
    print(io, Nto1Model, " with functions (")
    print(io, m.eval_diffeqs!, ", ")
    print(io, m.has_spiked, ", ")
    print(io, m.on_self_spike!, ") and ")
    print(io, length(m.inputs), " ", eltype(m.inputs), "s")
end
# "Nto1Model with functions (izh!, has_spiked, on_self_spike!) and 33 SpikingInputs"

const Model = Nto1Model  # mjeh.


"""
    SimState

Container for the data needed in the inner simulation loop ([`step!`](@ref)):
- Buffers overwritten each time step: the simulated variables `x`, and their time
  derivatives `ẋ`.
- The current and total number of simulation steps: `i` and `N`.
- Containers to record simulated signals (`spikes`, `v_rec`).
- User-supplied fixed parameters `p` and the integration timestep `Δt`.

Typically constructed via [`init_sim`](@ref).
"""
struct SimState{T, V<:AbstractVector{T}, P}
    i      ::RefValue{Int}
    N      ::Int
    Δt     ::T
    x      ::V
    ẋ      ::V
    p      ::P           # Can't have `P <: AbstractVector{T}`: not true for `NamedTuple`.
    v_rec  ::Vector{T}
    spikes ::Vector{T}
end
kw(s::SimState) = (; s.x..., s.p...)

step_str(s::SimState) = begin
    i = s.i[]
    N = s.N
    if     (i <  N)  "$i/$N"
    elseif (i == N)  "$i (complete)" end
end
Base.show(io::IO, s::SimState) =
    print(io, SimState, " [step ", step_str(s), ", ", length(s.spikes), " spikes]")


"""
    init_sim(x₀, p, T, Δt)

Initialize a [`SimState`](@ref) object using initial values for the simulated variables
`x₀`, parameters `p`, simulation length `T`, and integration timestep `Δt`.
"""
function init_sim(x₀, p, T, Δt)
    i = Ref(0)
    N = to_timesteps(T, Δt)
    # User can provide non-zero start time; but by default t₀ = 0s.
    t = get(x₀, :t, zero(T))
    # Initialize buffers:
    x = CVector{Float64}(; x₀..., t)
    # ↪ `ComponentArray(…)` cannot be type inferred!
    #    Hence, function boundary between this init and `step!`.
    ẋ = similar(x)  # = [∂xᵢ/∂t]
    ẋ .= 0
    ẋ.t = 1  # dt/dt = 1second/second
    # Where to record to
    v_rec = Vector{Float64}(undef, N)
    spikes = Vector{Float64}()
    return SimState(i, N, Δt, x, ẋ, p, v_rec, spikes)
end

"""
    step!(s::SimState, m::Model)

Inner loop body of the simulation. Update the state `s` by integrating differential
equations, handling incoming and self-generated spikes, and recording signals.
"""
function step!(s::SimState, m::Model)
    i = (s.i[] += 1)                    # Increase step counter
    (; Δt, x, ẋ, p, v_rec , spikes) = s  # Unpack state variables, for readability
    m.eval_diffeqs!(ẋ, kw(s))           # Calculate differentials
    x .+= ẋ .* Δt                       # Euler integration
    (; t, v) = x
    v_rec[i] = v                        # Record membrane voltage..
    if m.has_spiked(kw(s))
        push!(spikes, t)                # ..and self-spikes.
        m.on_self_spike!(x, kw(s))      # Apply spike discontinuity
    end
    for spiker in m.inputs
        N = count_new_spikes!(spiker, t)
        for _ in 1:N
            spiker.f!(x, kw(s))         # Apply the on-spike-arrival function
        end
    end
    return s                            # (By convention for mutating functions)
end

"""
    sim(m::Model, x₀, p, T, Δt)

Initialize the simulation state with [`init_sim(x₀, p, T, Δt)`](@ref), and [`step!`](@ref)
through it using the given `Model` equations `m`, until time `T` is reached. Return the
final state, which includes the recorded signals.
"""
function sim(m::Model, x₀, p, T, Δt)
    s = init_sim(x₀, p, T, Δt)
    num_steps = s.N
    for _ in 1:num_steps
        step!(s, m)
    end
    return s
end
