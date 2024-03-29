using JuMP, HiGHS, DataFrames

"""
CEM - Capacity Expansion Model

This function implements a capacity expansion model that minimises the total operation cost of a system. It determines optimal generation and storage capacities, power generation, storage charge and discharge, among others, while considering constraints such as budget, power balance, reserve requirements, and others.

Parameters:
- vreinfo: Information about variable renewable energy (VRE) sources.
- generatorinfo: Information about conventional generators.
- storageinfo: Information about long duration energy storage (LDES).
- halfhourlydemand: Half-hourly demand data.
- halfhourlyvrecf: Half-hourly VRE capacity factors.
- budget: Budget constraint (default: £30 billion).
- voll: Value of lost load (VoLL) (default: £100,000/MWh).
- cd_rho: Charge-discharge penalty (default: £10/MWh).
- reserve: Type of reserve requirements ("fixed", "spinning", "flexible", or "all") (default: "all").
- silent: Flag for silent mode during optimisation (default: true).

Returns:
A dictionary containing optimal values for decision variables and costs.
"""
function CEM(vreinfo, generatorinfo, storageinfo, halfhourlydemand, halfhourlyvrecf; 
    budget=30e9, voll=100e3, cd_rho=10, reserve="all", silent=true)

    # SETS
    V = vreinfo.id
    G = generatorinfo.id
    S = storageinfo.id
    T = halfhourlydemand.hh
    T1 = T[2:end]

    # INITIATE MODEL
    model = Model()
    set_optimizer(model, HiGHS.Optimizer)
    if silent
        set_silent(model)
    end

    # DECISION VARIABLES
    @variables(model, begin
        CAPG[G] >= 0
        CAPS[S] >= 0
        SOCM[S] >= 0
        GEN[G,T] >= 0
        R_GEN[G,T] >= 0
        SOC[S,T] >= 0
        CHARGE[S,T] >= 0
        DISCHARGE[S,T] >= 0
        R_DISCHARGE[S,T] >= 0
        CURTAIL[V,T] >= 0
        NSE[T] >= 0
    end)

    # OBJECTIVE FUNCTION
    @expression(model, C_EN, 
        sum(0.5 * generatorinfo[generatorinfo.id.==g,:varCost][1] * GEN[g,t] for g in G for t in T))
    @expression(model, C_RES,
        sum(0.5 * generatorinfo[generatorinfo.id.==g,:varCost][1] * R_GEN[g,t] for g in G for t in T))
    @expression(model, C_NSE, 
        sum(0.5 * voll * NSE[t] for t in T))
    @expression(model, C_CURT,
        sum(0.5 * vreinfo[vreinfo.id.==v,:varCost][1] * CURTAIL[v,t] for v in V for t in T))
    @expression(model, C_CD, 
        0.5 * cd_rho * sum(CHARGE[g,t] + DISCHARGE[g,t] for g in G for t in T))
    @objective(model, Min, 
        C_EN + C_RES + C_NSE + C_CURT + C_CD)

    # BUDGET CONSTRAINT
    @expression(model, C_Ginv, 
        sum(generatorinfo[generatorinfo.id.==g,:fixedCost][1] * CAPG[g] for g in G))
    @expression(model, C_SPinv, 
        sum(0.8e3 * storageinfo[storageinfo.id.==s,:bestCasePowerCost][1] * CAPS[s] for s in S))
    @expression(model, C_SEinv, 
        sum(0.8e3 * 0.5 * storageinfo[storageinfo.id.==s,:bestCaseEnergyCost][1] * SOCM[s] for s in S))
    @expression(model, TIC, C_Ginv + C_SPinv + C_SEinv)
    @constraint(model, c07, TIC <= budget)

    # POWER BALANCE CONSTRAINT
    @constraint(model, c08[t in T], 
        sum(GEN[g,t] for g in G) + NSE[t] - sum(CURTAIL[v,t] for v in V) +
        sum(vreinfo[vreinfo.id.==v,:installedMW][1] * 
        halfhourlyvrecf[(halfhourlyvrecf.hh.==t) .& (halfhourlyvrecf.vre_id.==v),:cf][1] for v in V) +
        sum(DISCHARGE[s,t] for s in S) - sum(CHARGE[s,t] for s in S) == 
        halfhourlydemand[halfhourlydemand.hh.==t,:load][1])
    
    # VRE RESERVE REQUIREMENT CONSTRAINT
    fixed = reserve == "fixed" || reserve == "all" ? 1 : 0
    spinning = reserve == "spinning" || reserve == "all" ? 1 : 0
    flexible = reserve == "flexible" || reserve == "all" ? 1 : 0
    @constraint(model, c09[t in T], 
        sum(R_GEN[g,t] for g in G) + sum(R_DISCHARGE[s,t] for s in S) >= 
        fixed * 1800 + 
        spinning * 0.03 * halfhourlydemand[halfhourlydemand.hh.==t,:load][1] + 
        flexible * (0.04 * (halfhourlyvrecf[halfhourlyvrecf.vre_id.==1,:cf][1] * 
                vreinfo[vreinfo.name.=="Solar",:installedMW][1]) + 0.1 * 
                (halfhourlyvrecf[halfhourlyvrecf.vre_id.==2,:cf][1] * 
                vreinfo[vreinfo.name.=="Onshore",:installedMW][1] + 
                halfhourlyvrecf[halfhourlyvrecf.vre_id.==3,:cf][1] * 
                vreinfo[vreinfo.name.=="Offshore",:installedMW][1])))
    
    # VRE CURTAIL CONSTRAINT
    @constraint(model, c11[v in V, t in T], 
        CURTAIL[v,t] <= vreinfo[vreinfo.id.==v,:installedMW][1] * 
        halfhourlyvrecf[(halfhourlyvrecf.hh.==t) .& (halfhourlyvrecf.vre_id.==v),:cf][1])
    
    # GENERATOR LIMIT CONSTRAINT
    @constraint(model, c14[g in G, t in T], GEN[g,t] + R_GEN[g,t] <= CAPG[g])

    # STORAGE CHARGE LIMIT CONSTRAINT
    @constraint(model, c15[s in S, t in T], CHARGE[s,t] <= CAPS[s])

    # STORAGE DISCHARGE LIMIT CONSTRAINT
    @constraint(model, c18[s in S, t in T], DISCHARGE[s,t] + R_DISCHARGE[s,t] <= CAPS[s])

    # STORAGE SOC LIMIT CONSTRAINT
    @constraint(model, c19[s in S, t in T], SOC[s,t] <= SOCM[s])

    # STORAGE SOC-RESERVE CONSTRAINT
    @constraint(model, c20[s in S, t in T], 
        (R_DISCHARGE[s,t] / storageinfo[storageinfo.id.==s,:bestCaseEff][1]) <= SOC[s,t])

    # GENERATOR RAMP UP CONSTRAINT
    @constraint(model, c21[g in G, t in T1], 
        GEN[g,t] - GEN[g,t-1] <= generatorinfo[generatorinfo.id.==g,:rampupRate][1] * CAPG[g])
    
    # GENERATOR RAMP DOWN CONSTRAINT
    @constraint(model, c22[g in G, t in T1],
        GEN[g,t-1] - GEN[g,t] <= generatorinfo[generatorinfo.id.==g,:rampdownRate][1] * CAPG[g])
    
    # STORAGE SOC UPDATE CONSTRAINT
    @constraint(model, c23[s in S, t in T1], 
        SOC[s,t] == SOC[s,t-1] + 
        (CHARGE[s,t] * storageinfo[storageinfo.id.==s,:bestCaseEff][1]) - 
        (DISCHARGE[s,t] / storageinfo[storageinfo.id.==s,:bestCaseEff][1]))

    # 50% SOC CONSTRAINT
    @constraint(model, c24a[s in S], SOC[s,minimum(T)] == 0.5 * SOCM[s])
    @constraint(model, c24b[s in S], SOC[s,maximum(T)] == 0.5 * SOCM[s])

    optimize!(model)

    return(
        CAPG = value.(CAPG).data,
        CAPS = value.(CAPS).data,
        SOCM = value.(SOCM).data,
        GEN = value.(GEN).data,
        R_GEN = value.(R_GEN).data,
        SOC = value.(SOC).data,
        CHARGE = value.(CHARGE).data,
        DISCHARGE = value.(DISCHARGE).data,
        R_DISCHARGE = value.(R_DISCHARGE).data,
        CURTAIL = value.(CURTAIL).data,
        NSE = value.(NSE).data,
        C_Ginv = value(C_Ginv),
        C_SPinv = value(C_SPinv),
        C_SEinv = value(C_SEinv),
        TIC = value(TIC),
        C_EN = value(C_EN),
        C_RES = value(C_RES),
        C_NSE = value(C_NSE),
        C_CURT = value(C_CURT),
        C_CD = value(C_CD),
        TOC = objective_value(model),
    )
end

"""
CEMnoLDES - Capacity Expansion Model with Long Duration Energy Storage

This function implements a capacity expansion model that minimises the total operation cost of a system. It determines optimal generation capacities and power generation, among others, while considering constraints such as budget, power balance, reserve requirements, and others.

Parameters:
- vreinfo: Information about variable renewable energy (VRE) sources.
- generatorinfo: Information about conventional generators.
- halfhourlydemand: Half-hourly demand data.
- halfhourlyvrecf: Half-hourly VRE capacity factors.
- budget: Budget constraint (default: £30 billion).
- voll: Value of lost load (VoLL) (default: £100,000/MWh).
- reserve: Type of reserve requirements ("fixed", "spinning", "flexible", or "all") (default: "all").
- silent: Flag for silent mode during optimisation (default: true).

Returns:
A dictionary containing optimal values for decision variables and costs.
"""
function CEMnoLDES(vreinfo, generatorinfo, halfhourlydemand, halfhourlyvrecf; 
    budget=30e9, voll=100e3, reserve="all", silent=true)

    # SETS
    V = vreinfo.id
    G = generatorinfo.id
    T = halfhourlydemand.hh
    T1 = T[2:end]

    # INITIATE MODEL
    model = Model()
    set_optimizer(model, HiGHS.Optimizer)
    if silent
        set_silent(model)
    end

    # DECISION VARIABLES
    @variables(model, begin
        CAPG[G] >= 0
        GEN[G,T] >= 0
        R_GEN[G,T] >= 0
        CURTAIL[V,T] >= 0
        NSE[T] >= 0
    end)

    # OBJECTIVE FUNCTION
    @expression(model, C_EN, 
        sum(0.5 * generatorinfo[generatorinfo.id.==g,:varCost][1] * GEN[g,t] for g in G for t in T))
    @expression(model, C_RES,
        sum(0.5 * generatorinfo[generatorinfo.id.==g,:varCost][1] * R_GEN[g,t] for g in G for t in T))
    @expression(model, C_NSE, 
        sum(0.5 * voll * NSE[t] for t in T))
    @expression(model, C_CURT,
        sum(0.5 * vreinfo[vreinfo.id.==v,:varCost][1] * CURTAIL[v,t] for v in V for t in T))
    @objective(model, Min, 
        C_EN + C_RES + C_NSE + C_CURT)

    # BUDGET CONSTRAINT
    @expression(model, C_Ginv, 
        sum(generatorinfo[generatorinfo.id.==g,:fixedCost][1] * CAPG[g] for g in G))
    @expression(model, TIC, C_Ginv)
    @constraint(model, c07, TIC <= budget)

    # POWER BALANCE CONSTRAINT
    @constraint(model, c08[t in T], 
        sum(GEN[g,t] for g in G) + NSE[t] - sum(CURTAIL[v,t] for v in V) +
        sum(vreinfo[vreinfo.id.==v,:installedMW][1] * 
        halfhourlyvrecf[(halfhourlyvrecf.hh.==t) .& (halfhourlyvrecf.vre_id.==v),:cf][1] for v in V) == 
        halfhourlydemand[halfhourlydemand.hh.==t,:load][1])
    
    # VRE RESERVE REQUIREMENT CONSTRAINT
    fixed = reserve == "fixed" || reserve == "all" ? 1 : 0
    spinning = reserve == "spinning" || reserve == "all" ? 1 : 0
    flexible = reserve == "flexible" || reserve == "all" ? 1 : 0
    @constraint(model, c09[t in T], 
        sum(R_GEN[g,t] for g in G) >= 
        fixed * 1800 + 
        spinning * 0.03 * halfhourlydemand[halfhourlydemand.hh.==t,:load][1] + 
        flexible * (0.04 * (halfhourlyvrecf[halfhourlyvrecf.vre_id.==1,:cf][1] * 
                vreinfo[vreinfo.name.=="Solar",:installedMW][1]) + 0.1 * 
                (halfhourlyvrecf[halfhourlyvrecf.vre_id.==2,:cf][1] * 
                vreinfo[vreinfo.name.=="Onshore",:installedMW][1] + 
                halfhourlyvrecf[halfhourlyvrecf.vre_id.==3,:cf][1] * 
                vreinfo[vreinfo.name.=="Offshore",:installedMW][1])))
    
    # VRE CURTAIL CONSTRAINT
    @constraint(model, c11[v in V, t in T], 
        CURTAIL[v,t] <= vreinfo[vreinfo.id.==v,:installedMW][1] * 
        halfhourlyvrecf[(halfhourlyvrecf.hh.==t) .& (halfhourlyvrecf.vre_id.==v),:cf][1])
    
    # GENERATOR LIMIT CONSTRAINT
    @constraint(model, c14[g in G, t in T], GEN[g,t] + R_GEN[g,t] <= CAPG[g])

    # GENERATOR RAMP UP CONSTRAINT
    @constraint(model, c21[g in G, t in T1], 
        GEN[g,t] - GEN[g,t-1] <= generatorinfo[generatorinfo.id.==g,:rampupRate][1] * CAPG[g])
    
    # GENERATOR RAMP DOWN CONSTRAINT
    @constraint(model, c22[g in G, t in T1],
        GEN[g,t-1] - GEN[g,t] <= generatorinfo[generatorinfo.id.==g,:rampdownRate][1] * CAPG[g])

    optimize!(model)

    return(
        CAPG = value.(CAPG).data,
        GEN = value.(GEN).data,
        R_GEN = value.(R_GEN).data,
        CURTAIL = value.(CURTAIL).data,
        NSE = value.(NSE).data,
        C_Ginv = value(C_Ginv),
        TIC = value(TIC),
        C_EN = value(C_EN),
        C_RES = value(C_RES),
        C_NSE = value(C_NSE),
        C_CURT = value(C_CURT),
        TOC = objective_value(model),
    )
end