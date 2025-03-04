#= 

# 2D Curl-Preserving L2-Bestapproximation
([source code](SOURCE_URL))

This example computes the L2-bestapproximation of some given vector-valued function into the lowest-order Nedelec space. It also
preserves the curl of the function in the sense that the curl of the approximation equals the piecewise integral mean of the exact curl.
Afterwards the L2 error (also of the curl) is computed and the solution is plotted.

=#

module Example_2DBestapproxCurlpreserve

using GradientRobustMultiPhysics
using ExtendableGrids

## define some vector field that should be approximated
function exact_function!(result,x::Array{<:Real,1})
    result[1] = x[1]^3+x[2]^2
    result[2] = -x[1]^2 + x[2] + 1
end
## define its curl = -du2/dx1 + du1/dx2
function exact_curl!(result,x::Array{<:Real,1})
    result[1] = 2 * x[2] + 2 * x[1]
end

## everything is wrapped in a main function
function main(; verbosity = 0, Plotter = nothing)

    ## set log level
    set_verbosity(verbosity)

    ## generate a unit square mesh and refine
    xgrid = simplexgrid([0.0,1.0],[0.0,1.0])
    xgrid = uniform_refine(xgrid,4)

    ## negotiate exact_function! and exact_curl! to the package
    user_function = DataFunction(exact_function!, [2,2]; name = "u", dependencies = "X", quadorder = 3)
    user_function_curl = DataFunction(exact_curl!, [1,2]; name = "curl(u)", dependencies = "X", quadorder = 1)
    
    ## setup a bestapproximation problem via a predefined prototype
    Problem = L2BestapproximationProblem(user_function; bestapprox_boundary_regions = [1,2,3,4])

    ## add a new unknown (Lagrange multiplier that handles the curl constraint)
    ## here 1 is the number of components (it is scalar-valued) and 2 is the space dimension
    add_unknown!(Problem; unknown_name = "p", equation_name = "curl constraint")
    add_operator!(Problem, [1,2], LagrangeMultiplier(Curl2D))

    ## add the right-hand side data for the constraint and inspect the defined problem
    add_rhsdata!(Problem, 2, RhsOperator(Identity, [0], user_function_curl))
    @show Problem

    ## choose some (inf-sup stable) finite element types
    FEType = [HCURLN0{2}, H1P0{1}]
    FES = [FESpace{FEType[1]}(xgrid),FESpace{FEType[2]}(xgrid)]

    ## create a solution vector and solve the problem
    Solution = FEVector{Float64}(["u_h","p_h"],FES)
    solve!(Solution, Problem)

    ## calculate L2 error and L2 curl error
    L2ErrorEvaluator = L2ErrorIntegrator(Float64, user_function, Identity)
    L2CurlErrorEvaluator = L2ErrorIntegrator(Float64, user_function_curl, Curl2D)
    println("|| u - u_h || = $(sqrt(evaluate(L2ErrorEvaluator,Solution[1])))")
    println("|| curl(u - u_h) || = $(sqrt(evaluate(L2CurlErrorEvaluator,Solution[1])))")
       
    ## plot
    GradientRobustMultiPhysics.plot(xgrid, [Solution[1], Solution[1]], [Identity, Curl2D]; Plotter = Plotter)
end

end

#=
### Output of default main() run
=#
Example_2DBestapproxCurlpreserve.main()