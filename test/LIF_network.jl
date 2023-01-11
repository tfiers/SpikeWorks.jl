using SpikeWorks

@Neuron LIFNeuronn begin
    v::Float64 = 0
end
SpikeWorks.update_derivatives!(n::LIFNeuronn) =
    let Dₜ = derivatives(n),
        v = vars(n).v

    Dₜ.v = -v
end
SpikeWorks.has_spiked(n::LIFNeuronn)     = (vars(n).v > 1)
SpikeWorks.on_self_spike!(n::LIFNeuronn) = (vars(n).v = 0)

# or:
# update_diffeqs!(::LIFNeuronn, Dₜ, v)
#     Dₜ.v = -v
# end
