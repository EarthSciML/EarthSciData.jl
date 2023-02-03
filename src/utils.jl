"""
$(SIGNATURES)

Remove equations from a PDESystem where a variable in the LHS contains the given prefix but
none of the equations have an RHS containing that variable. This can be used to 
remove data loading equations that are not used in the final model.
"""
function prune!(pde_sys::PDESystem, prefix::AbstractString)
    rhs_vars = []
    for eq in equations(pde_sys)
        for var in Symbolics.get_variables(eq.rhs)
            push!(rhs_vars, var)
        end
    end
    rhs_vars = Symbolics.tosymbol.(unique(rhs_vars); escape=true)
    deleteindex = []
    for (i, eq) ∈ enumerate(equations(pde_sys))
        lhsvars = Symbolics.tosymbol.(Symbolics.get_variables(eq.lhs); escape=true)
        hasprefix = startswith.(string.(lhsvars), prefix)
        # Only keep equations where all variables on the LHS containing the given
        # prefix are also on the RHS of at least one equation.
        if sum(hasprefix) > 0
            if !all((var) -> var ∈ rhs_vars, lhsvars[hasprefix])
                push!(deleteindex, i)
            end
        end
    end
    deleteat!(pde_sys.eqs, deleteindex)
    return pde_sys
end
