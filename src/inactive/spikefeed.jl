"""
    SpikeFeed(sorted_spike_times)

Keeps track of how many spikes have been processed already.

Used with [`advance_to!`](@ref) in the simulation loop, to check whether an input spike
train has spiked in the current timestep (and if so, how many times).

See [Usage](@ref).
"""
struct SpikeFeed
    spikes  ::Vector{Float64}  # Spike times, assumed sorted
    next    ::RefValue{Int}    # Index of next unseen spike
end
SpikeFeed(spikes) = SpikeFeed(spikes, Ref(1))

time_of_next(sf::SpikeFeed) = sf.spikes[sf.next[]]
is_exhausted(sf::SpikeFeed) = sf.next[] > length(sf.spikes)

"""
    n = advance_to!(sf::SpikeFeed, t)

Count the number of spikes `n` in the time interval `(tₚ, t]`,
where `tₚ` is the time `t` this method was last called with.
(On the first call, count all spikes before `t`).

When used in a simulation loop, `t - tₚ` will typically be the timestep, `Δt`.

See [Usage](@ref).
"""
advance_to!(sf::SpikeFeed, t) = begin
    n = 0
    while !is_exhausted(sf) && (@inbounds time_of_next(sf) ≤ t)
        n += 1
        sf.next[] += 1
    end
    return n
end


num_processed(sf::SpikeFeed) = sf.next[] - 1
num_total(sf::SpikeFeed) = length(sf.spikes)

Base.show(io::IO, sf::SpikeFeed) = begin
    print(io, SpikeFeed, " [", num_processed(sf), "/", num_total(sf), "] ")
    if is_exhausted(sf)
        print(io, "(exhausted)")
    else
        print(io, "(next: ", time_of_next(sf), ")")
    end
end
