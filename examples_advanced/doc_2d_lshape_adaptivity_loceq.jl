#= 

# 2D Equilibration Error Estimation (Local)
([source code](SOURCE_URL))

This example computes a local equilibration error estimator for the $H^1$ error of some $H^1$-conforming
approximation ``u_h`` to the solution ``u`` of some Poisson problem ``-\Delta u = f`` on an L-shaped domain, i.e.
```math
\eta^2(\sigma_h) := \| \sigma_h - \nabla u_h \|^2_{L^2(T)}
```
where ``\sigma_h`` discretisates the exact ``\sigma`` in the dual mixed problem
```math
\sigma - \nabla u = 0
\quad \text{and} \quad
\mathrm{div}(\sigma) + f = 0
```
by some local equilibration strategy, see reference below for details.

This examples demonstrates the use of low-level structures to assemble individual problems
and a strategy solve several small problems in parallel.

!!! reference

    ''A posteriori error estimates for efficiency and error control in numerical simulations''
    Lecture Notes by M. Vohralik
    [>Link<](https://who.rocq.inria.fr/Martin.Vohralik/Enseig/APost/a_posteriori.pdf)

=#


module Example_LEQLshape

using GradientRobustMultiPhysics
using ExtendableGrids
using ExtendableSparse
using Printf

## exact solution u for the Poisson problem
function exact_function!(result,x::Array{<:Real,1})
    result[1] = atan(x[2],x[1])
    if result[1] < 0
        result[1] += 2*pi
    end
    result[1] = sin(2*result[1]/3)
    result[1] *= (x[1]^2 + x[2]^2)^(1/3)
end
## ... and its gradient
function exact_function_gradient!(result,x::Array{<:Real,1})
    result[1] = atan(x[2],x[1])
    if result[1] < 0
        result[1] += 2*pi
    end
    ## du/dy = du/dr * sin(phi) + (1/r) * du/dphi * cos(phi)
    result[2] = sin(2*result[1]/3) * sin(result[1]) + cos(2*result[1]/3) * cos(result[1])
    result[2] *= (x[1]^2 + x[2]^2)^(-1/6) * 2/3 
    ## du/dx = du/dr * cos(phi) - (1/r) * du/dphi * sin(phi)
    result[1] = sin(2*result[1]/3) * cos(result[1]) - cos(2*result[1]/3) * sin(result[1])
    result[1] *= (x[1]^2 + x[2]^2)^(-1/6) * 2/3 
end

## everything is wrapped in a main function
function main(; verbosity = 0, nlevels = 15, theta = 1//2, Plotter = nothing)

    ## set log level
    set_verbosity(verbosity)

    ## initial grid
    xgrid = grid_lshape(Triangle2D)

    ## choose some finite elements for primal and dual problem (= for equilibrated fluxes)
    ## (local equilibration for Pk needs at least BDMk)
    FEType = H1P1{1}
    FETypeDual = HDIVBDM1{2}
    
    ## negotiate data functions to the package
    user_function = DataFunction(exact_function!, [1,2]; name = "u", dependencies = "X", quadorder = 5)
    user_function_gradient = DataFunction(exact_function_gradient!, [2,2]; name = "∇(u)", dependencies = "X", quadorder = 4)

    ## setup Poisson problem
    Problem = PoissonProblem()
    add_boundarydata!(Problem, 1, [2,3,4,5,6,7], BestapproxDirichletBoundary; data = user_function)
    add_boundarydata!(Problem, 1, [1,8], HomogeneousDirichletBoundary)

    ## define error estimator : || sigma_h - nabla u_h ||^2_{L^2(T)}
    ## this can be realised via a kernel function
    function eqestimator_kernel(result, input)
        ## input = [Identity(sigma_h), Divergence(sigma_h), Gradient(u_h)]
        result[1] = (input[1] - input[4])^2 + (input[2] - input[5])^2
        result[2] = input[3]^2
        return nothing
    end
    estimator_action = Action(Float64,ActionKernel(eqestimator_kernel, [2,5]; name = "estimator kernel", dependencies = "", quadorder = 3))
    EQIntegrator = ItemIntegrator(Float64,ON_CELLS,[Identity, Divergence, Gradient],estimator_action)

    ## setup exact error evaluations
    L2ErrorEvaluator = L2ErrorIntegrator(Float64, user_function, Identity)
    H1ErrorEvaluator = L2ErrorIntegrator(Float64, user_function_gradient, Gradient)
    L2ErrorEvaluatorDual = L2ErrorIntegrator(Float64, user_function_gradient, Identity)

    ## refinement loop (only uniform for now)
    NDofs = zeros(Int, nlevels)
    NDofsDual = zeros(Int, nlevels)
    Results = zeros(Float64, nlevels, 4)
    Solution = nothing
    for level = 1 : nlevels

        ## create a solution vector and solve the problem
        FES = FESpace{FEType}(xgrid)
        Solution = FEVector{Float64}("u_h",FES)
        solve!(Solution, Problem)
        NDofs[level] = length(Solution[1])

        ## evaluate eqilibration error estimator adn append it to Solution vector (for plotting etc.)
        DualSolution = get_local_equilibration_estimator(xgrid, Solution, FETypeDual)
        NDofsDual[level] = length(DualSolution.entries)
        FES_eta = FESpace{H1P0{1}}(xgrid)
        append!(Solution, "σ_h",FES_eta)
        error4cell = zeros(Float64,2,num_sources(xgrid[CellNodes]))
        evaluate!(error4cell, EQIntegrator, [DualSolution[1], DualSolution[1], Solution[1]])
        for j = 1 : num_sources(xgrid[CellNodes])
            Solution[2][j] = error4cell[1,j] + error4cell[2,j]
        end

        if verbosity > 0
            println("\n  SOLVE LEVEL $level")
            println("    ndofs = $(NDofs[level])")
            println("    ndofsDual = $(NDofsDual[level])")
        end

        ## calculate L2 error, H1 error, estimator, dual L2 error and write to results
        Results[level,1] = sqrt(evaluate(L2ErrorEvaluator,[Solution[1]]))
        Results[level,2] = sqrt(evaluate(H1ErrorEvaluator,[Solution[1]]))
        Results[level,3] = sqrt(sum(Solution[2][:]))
        Results[level,4] = sqrt(evaluate(L2ErrorEvaluatorDual,[DualSolution[1]]))
        if verbosity > 0
            println("  ESTIMATE")
            println("    estim H1 error = $(Results[level,3])")
            println("    exact H1 error = $(Results[level,2])")
            println("     dual L2 error = $(Results[level,4])")
        end

        if level == nlevels
            break;
        end

        ## mesh refinement
        if theta >= 1
            ## uniform mesh refinement
            xgrid = uniform_refine(xgrid)
        else
            ## adaptive mesh refinement
            ## refine by red-green-blue refinement (incl. closuring)
            facemarker = bulk_mark(xgrid, Solution[2], theta)
            xgrid = RGB_refine(xgrid, facemarker)
        end
    end
    
    ## plot
    GradientRobustMultiPhysics.plot(xgrid, [Solution[1]], [Identity]; add_grid_plot = true, Plotter = Plotter)
    
    ## print results
    @printf("\n  NDOFS  |   L2ERROR      order   |   H1ERROR      order   | H1-ESTIMATOR   order      efficiency   ")
    @printf("\n=========|========================|========================|========================================\n")
    order = 0
    for j=1:nlevels
        @printf("  %6d |",NDofs[j]);
        for k = 1 : 3
            if j > 1
                order = log(Results[j-1,k]/Results[j,k]) / (log(NDofs[j]/NDofs[j-1])/2)
            end
            @printf(" %.5e ",Results[j,k])
            if k == 3
                @printf("   %.3f       %.3f",order,Results[j,k]/Results[j,k-1])
            else
                @printf("   %.3f   |",order)
            end
        end
        @printf("\n")
    end
    
end


## this function computes the local equilibrated fluxes
## by solving local problems on (disjunct group of) node patches
function get_local_equilibration_estimator(xgrid, Solution, FETypeDual; verbosity::Int = 1)
    ## needed grid stuff
    xCellNodes::Array{Int32,2} = xgrid[CellNodes]
    xCellFaces::Array{Int32,2} = xgrid[CellFaces]
    xFaceNodes::Array{Int32,2} = xgrid[FaceNodes]
    xCellVolumes::Array{Float64,1} = xgrid[CellVolumes]
    xNodeCells = atranspose(xCellNodes)
    nnodes::Int = num_sources(xNodeCells)
    nfaces::Int = num_sources(xFaceNodes)

    ## get node patch groups that can be solved in parallel
    group4node = xgrid[NodePatchGroups]

    ## init equilibration space (and Lagrange multiplier space)
    FEType = eltype(Solution[1].FES)
    FESDual = FESpace{FETypeDual}(xgrid)
    xItemDofs::Union{VariableTargetAdjacency{Int32},SerialVariableTargetAdjacency{Int32},Array{Int32,2}} = FESDual[CellDofs]
    xFaceDofs::Union{VariableTargetAdjacency{Int32},SerialVariableTargetAdjacency{Int32},Array{Int32,2}} = FESDual[FaceDofs]
    xItemDofs_uh::Union{VariableTargetAdjacency{Int32},SerialVariableTargetAdjacency{Int32},Array{Int32,2}} = Solution[1].FES[CellDofs]
    DualSolution = FEVector{Float64}("σ_h",FESDual)
    
    ## partition of unity and their gradients
    POUFEType = H1P1{1}
    POUFES = FESpace{POUFEType}(xgrid)
    POUqf = QuadratureRule{Float64,Triangle2D}(0)

    ## quadrature formulas
    qf = QuadratureRule{Float64,Triangle2D}(2*get_polynomialorder(FETypeDual, Triangle2D))
    weights::Array{Float64,1} = qf.w

    ## some constants
    dofs_on_face::Int = max_num_targets_per_source(xFaceDofs)
    div_penalty::Float64 = 1e5
    bnd_penalty::Float64 = 1e30
    maxcells::Int = max_num_targets_per_source(xNodeCells)
    maxdofs::Int = max_num_targets_per_source(xItemDofs)
    maxdofs_uh::Int = max_num_targets_per_source(xItemDofs_uh)

    ## redistribute groups for more equilibrated thread load (first groups are larger)
    maxgroups = maximum(group4node)
    groups = Array{Int,1}(1 : maxgroups)
    for j::Int = 1 : floor(maxgroups/2)
        a = groups[j]
        groups[j] = groups[2*j]
        groups[2*j] = a
    end
    X = Array{Array{Float64,1},1}(undef,maxgroups)

    Threads.@threads for group in groups
        grouptime = @elapsed begin
        @info "  Starting equilibrating patch group $group on thread $(Threads.threadid())... "
        ## temporary variables
        localnode::Int = 0
        graduh = zeros(Float64,2)
        gradphi = zeros(Float64,2)
        coeffs_uh = zeros(Float64, maxdofs_uh)
        eval_i = zeros(Float64,2)
        eval_j = zeros(Float64,2)
        eval_phi = zeros(Float64,1)
        cell::Int = 0
        dofi::Int = 0
        dofj::Int = 0
        weight::Float64 = 0
        temp::Float64 = 0
        temp2::Float64 = 0
        temp3::Float64 = 0
        Alocal = zeros(Float64,maxdofs,maxdofs)
        blocal = zeros(Float64,maxdofs)

        ## init FEBasiEvaluator
        FEBasis_gradphi = FEBasisEvaluator{Float64,POUFEType,Triangle2D,Gradient,ON_CELLS}(POUFES, POUqf)
        FEBasis_xref = FEBasisEvaluator{Float64,POUFEType,Triangle2D,Identity,ON_CELLS}(POUFES, qf)
        FEBasis_graduh = FEBasisEvaluator{Float64,FEType,Triangle2D,Gradient,ON_CELLS}(Solution[1].FES, qf)
        FEBasis_div = FEBasisEvaluator{Float64,FETypeDual,Triangle2D,Divergence,ON_CELLS}(FESDual, qf)
        FEBasis_id = FEBasisEvaluator{Float64,FETypeDual,Triangle2D,Identity,ON_CELLS}(FESDual, qf)

        ## init system
        A = ExtendableSparseMatrix{Float64,Int}(FESDual.ndofs,FESDual.ndofs)
        b = zeros(Float64,FESDual.ndofs)
        X[group] = zeros(Float64,FESDual.ndofs)
        x = zeros(Float64,FESDual.ndofs)

        ## find dofs at boundary of node patches
        is_boundarydof = zeros(Bool,FESDual.ndofs)
        boundary_face::Bool = false
        for face = 1 : nfaces
            boundary_face = true
            for k = 1 : 2
                if group4node[xFaceNodes[k,face]] == group
                    boundary_face = false
                    break
                end
            end
            if (boundary_face)
                for j = 1 : dofs_on_face
                    is_boundarydof[xFaceDofs[j,face]] = true
                end
            end
        end

        for node = 1 : nnodes
        if group4node[node] == group
            for c = 1 : num_targets(xNodeCells,node)
                cell = xNodeCells[c,node]

                ## find local node number of global node z
                ## and evaluate (constatn) gradient of nodal basis function phi_z
                localnode = 1
                while xCellNodes[localnode,cell] != node
                    localnode += 1
                end
                update!(FEBasis_gradphi,cell)
                eval!(gradphi, FEBasis_gradphi, localnode, 1)

                ## read coefficients for discrete flux
                for j=1:maxdofs_uh
                    coeffs_uh[j] = Solution[1].entries[xItemDofs_uh[j,cell]]
                end

                ## update other FE evaluators
                update!(FEBasis_graduh,cell)
                update!(FEBasis_div,cell)
                update!(FEBasis_id,cell)

                ## assembly on this cell
                for i in eachindex(weights)
                    weight = weights[i] * xCellVolumes[cell]

                    ## evaluate grad(u_h) and nodal basis function at quadrature point
                    fill!(graduh,0)
                    eval!(graduh, FEBasis_graduh, coeffs_uh, i)
                    eval!(eval_phi, FEBasis_xref, localnode, i)

                    ## compute residual -f*phi_z + grad(u_h) * grad(phi_z) at quadrature point i ( f = 0 in this example !!! )
                    temp = div_penalty * sqrt(xCellVolumes[cell]) * ( graduh[1] * gradphi[1] + graduh[2] * gradphi[2] ) * weight
                    temp2 = div_penalty * sqrt(xCellVolumes[cell]) *weight
                    for dof_i = 1 : maxdofs
                        eval!(eval_i, FEBasis_id, dof_i, i)
                        eval_i .*= weight
                        ## right-hand side for best-approximation (grad(u_h)*phi)
                        blocal[dof_i] += (graduh[1]*eval_i[1] + graduh[2]*eval_i[2]) * eval_phi[1]
                        ## mass matrix Hdiv 
                        for dof_j = 1 : maxdofs
                            eval!(eval_j, FEBasis_id, dof_j, i)
                            Alocal[dof_i,dof_j] += (eval_i[1]*eval_j[1] + eval_i[2]*eval_j[2])
                        end
                        ## div-div matrix Hdiv * penalty (quick and dirty to avoid Lagrange multiplier)
                        eval!(eval_i, FEBasis_div, dof_i, i)
                        blocal[dof_i] += temp * eval_i[1]
                        temp3 = temp2 * eval_i[1]
                        for dof_j = 1 : maxdofs
                            eval!(eval_j, FEBasis_div, dof_j, i)
                            Alocal[dof_i,dof_j] += temp3*eval_j[1]
                        end
                    end
                end  

                ## write into global A and b
                for dof_i = 1 : maxdofs
                    dofi = xItemDofs[dof_i,cell]
                    b[dofi] += blocal[dof_i]
                    for dof_j = 1 : maxdofs
                        dofj = xItemDofs[dof_j,cell]
                        _addnz(A,dofi,dofj,Alocal[dof_i,dof_j],1)
                    end
                end

                ## reset local A and b
                fill!(Alocal,0)
                fill!(blocal,0)
            end
        end
        end 

        ## penalize dofs at boundary of node patches
        for j = 1 : FESDual.ndofs
            if is_boundarydof[j]
                A[j,j] = bnd_penalty
                b[j] = 0
            end
        end

        ## solve local problem   
        X[group] .= A\b
    end

    @info "Finished equilibration patch group $group on thread $(Threads.threadid()) in $(grouptime)s "
    end

    ## write local solutions to global vector
    for group = 1 : maxgroups
        DualSolution[1].entries .+= X[group]
    end

    return DualSolution
end

end