
AdEx = @model begin
    Iₗ  = -gₗ*(V-Eₗ)
    Iₑₓ = gₗ*Δₜ*exp((V-Vₜ)/Δₜ)
    dV/dt = (Iₗ + Iₑₓ - w + Iₛ) / C
    dw/dt = (a*(V-Eₗ) - w) / τw

    @spike if V > 0mV
        V = Vᵣ
        w += b
    end
end
