
using Firework: process_eqs!

izh_expr = quote

    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    du/dt = a*(b*(v-vᵣ) - u)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    d(gₑ)/dt = -gₑ / τ
    dgᵢ  /dt = -gᵢ / τ

    @spike if v > v_peak
        v = v_reset
        u += Δu
    end
end

out = process_eqs!(izh_expr)
