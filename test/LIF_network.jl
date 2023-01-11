using SpikeWorks

@Neuron LIFNeuron begin
    v::Float64 = 0
end
update_diffeqs!(n::LIFNeuron) = let Dₜ = derivatives(n), v = vars(n).v
    Dₜ.v = -v
end
has_spiked(n::LIFNeuron)     = (vars(n).v > 1)
on_self_spike!(n::LIFNeuron) = (vars(n).v = 0)

# or:
# update_diffeqs!(::LIFNeuron, Dₜ, v)
#     Dₜ.v = -v
# end
