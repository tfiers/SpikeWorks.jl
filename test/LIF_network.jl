using SpikeWorks
import SpikeWorks as SW

@Neuron LIFNeuronn begin
    v::Float64 = 0
end
SW.update_derivatives!(n::LIFNeuronn) = let Dₜ = derivatives(n),
                                            v = vars(n).v
    Dₜ.v = -v
end
SW.has_spiked(n::LIFNeuronn)     = (vars(n).v > 1)
SW.on_self_spike!(n::LIFNeuronn) = (vars(n).v = 0)

# or:
# update_diffeqs!(::LIFNeuronn, Dₜ, v)
#     Dₜ.v = -v
# end
