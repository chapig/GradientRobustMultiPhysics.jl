using Test
using ExtendableGrids
using GradientRobustMultiPhysics

include("test_jumps.jl")

function run_basis_tests()

    function testgrid(::Type{Edge1D})
        return uniform_refine(simplexgrid([0.0,1//4,2//3,1.0]),1)
    end
    function testgrid(EG::Type{<:AbstractElementGeometry2D})
        return uniform_refine(grid_unitsquare(EG),1)
    end
    function testgrid(EG::Type{<:AbstractElementGeometry3D})
        return uniform_refine(grid_unitcube(EG),1)
    end
    function testgrid(::Type{Triangle2D},::Type{Parallelogram2D})
        return uniform_refine(grid_unitsquare_mixedgeometries(),1)
    end

    tolerance = 5e-12

    function exact_function1D(polyorder)
        function polynomial(result,x::Array{<:Real,1})
            result[1] = x[1]^polyorder + 1
        end
        function gradient(result,x::Array{<:Real,1})
            result[1] = polyorder * x[1]^(polyorder-1)
        end
        function hessian(result,x::Array{<:Real,1})
            result[1] = polyorder * (polyorder - 1) * x[1]^(polyorder-2)
        end
        exact_integral = 1 // (polyorder+1) + 1
        exact_function = DataFunction(polynomial, [1,1]; dependencies = "X", quadorder = polyorder)
        exact_gradient = DataFunction(gradient, [1,1]; dependencies = "X", quadorder = polyorder - 1)
        exact_hessian = DataFunction(hessian, [1,1]; dependencies = "X", quadorder = polyorder - 2)
        return exact_function, exact_integral, exact_gradient, exact_hessian
    end

    function exact_function2D(polyorder)
        function polynomial(result,x::Array{<:Real,1})
            result[1] = x[1]^polyorder + 2*x[2]^polyorder + 1
            result[2] = 3*x[1]^polyorder - x[2]^polyorder - 1
        end
        function gradient(result,x::Array{<:Real,1})
            result[1] = polyorder * x[1]^(polyorder-1)
            result[2] = 2 * polyorder * x[2]^(polyorder - 1)
            result[3] = 3 * polyorder * x[1]^(polyorder-1)
            result[4] = - polyorder * x[2]^(polyorder - 1)
        end
        function hessian(result,x::Array{<:Real,1})
            result[1] = polyorder * (polyorder - 1) * x[1]^(polyorder-2)
            result[2] = 0
            result[3] = 0
            result[4] = 2 * polyorder * (polyorder - 1) * x[2]^(polyorder-2)
            result[5] = 3 * polyorder * (polyorder - 1) * x[1]^(polyorder-2)
            result[6] = 0
            result[7] = 0
            result[8] = - polyorder * (polyorder - 1) * x[2]^(polyorder-2)
        end
        exact_integral = [3 // (polyorder+1) + 1, 2 // (polyorder+1) - 1]
        exact_function = DataFunction(polynomial, [2,2]; dependencies = "X", quadorder = polyorder)
        exact_gradient = DataFunction(gradient, [4,2]; dependencies = "X", quadorder = polyorder - 1)
        exact_hessian = DataFunction(hessian, [8,2]; dependencies = "X", quadorder = polyorder - 2)
        return exact_function, exact_integral, exact_gradient, exact_hessian
    end

    function exact_function3D(polyorder)
        function polynomial(result,x::Array{<:Real,1})
            result[1] = 2*x[3]^polyorder - x[2]^polyorder - 1
            result[2] = x[1]^polyorder + 2*x[2]^polyorder + 1
            result[3] = 3*x[1]^polyorder - x[2]^polyorder - 1
        end
        function gradient(result,x::Array{<:Real,1})
            result[1] = 0
            result[2] = - polyorder * x[2]^(polyorder - 1)
            result[3] = 2 * polyorder * x[3]^(polyorder - 1)
            result[4] = polyorder * x[1]^(polyorder-1)
            result[5] = 2 * polyorder * x[2]^(polyorder - 1)
            result[7] = 3 * polyorder * x[1]^(polyorder-1)
            result[8] = - polyorder * x[2]^(polyorder - 1)
            result[9] = 0
        end
        function hessian(result,x::Array{<:Real,1})
            fill!(result,0)
            result[5] = - polyorder * (polyorder - 1) * x[2]^(polyorder-2)
            result[9] = 2 * polyorder * (polyorder - 1) * x[3]^(polyorder-2)
            result[10] = polyorder * (polyorder - 1) * x[1]^(polyorder-2)
            result[14] = 2 * polyorder * (polyorder - 1) * x[2]^(polyorder-2)
            result[19] = 3 * polyorder * (polyorder - 1) * x[1]^(polyorder-2)
            result[23] = - polyorder * (polyorder - 1) * x[2]^(polyorder-2)
        end
        exact_integral = [1 // (polyorder + 1) - 1, 3 // (polyorder+1) + 1, 2 // (polyorder+1) - 1]
        exact_function = DataFunction(polynomial, [3,3]; dependencies = "X", quadorder = polyorder)
        exact_gradient = DataFunction(gradient, [9,3]; dependencies = "X", quadorder = polyorder - 1)
        exact_hessian = DataFunction(hessian, [27,3]; dependencies = "X", quadorder = polyorder - 2)
        return exact_function, exact_integral, exact_gradient, exact_hessian
    end

    ############################
    # TESTSET QUADRATURE RULES #
    ############################
    maxorder1D = 12
    EG2D = [Triangle2D,Parallelogram2D]
    maxorder2D = [20,20]
    EG3D = [Parallelepiped3D,Tetrahedron3D]
    maxorder3D = [12,8]

    @testset "QuadratureRules" begin
        println("\n")
        println("=============================")
        println("Testing QuadratureRules in 1D")
        println("=============================")
        xgrid = testgrid(Edge1D)
        for order = 1 : maxorder1D
            integrand, exactvalue = exact_function1D(order)
            qf = QuadratureRule{Float64,Edge1D}(order)
            quadvalue = integrate(xgrid, ON_CELLS, integrand, length(exactvalue); force_quadrature_rule = qf)
            println("EG = Edge1D | order = $order ($(qf.name), $(length(qf.w)) points) | error = $(quadvalue - exactvalue)")
            @test isapprox(quadvalue,exactvalue)
        end
        println("\n")
        println("=============================")
        println("Testing QuadratureRules in 2D")
        println("=============================")
        for j = 1 : length(EG2D)
            EG = EG2D[j]
            xgrid = testgrid(EG)
            for order = 1 : maxorder2D[j]
                integrand, exactvalue = exact_function2D(order)
                qf = QuadratureRule{Float64,EG}(order)
                quadvalue = integrate(xgrid, ON_CELLS, integrand, length(exactvalue); force_quadrature_rule = qf)
                println("EG = $EG | order = $order ($(qf.name), $(length(qf.w)) points) | error = $(quadvalue - exactvalue)")
                @test isapprox(quadvalue,exactvalue)
            end
        end
        println("\n")
        println("=============================")
        println("Testing QuadratureRules in 3D")
        println("=============================")
        for j = 1 : length(EG3D)
            EG = EG3D[j]
            xgrid = testgrid(EG)
            for order = 1 : maxorder3D[j]
                integrand, exactvalue = exact_function3D(order)
                qf = QuadratureRule{Float64,EG}(order)
                quadvalue = integrate(xgrid, ON_CELLS, integrand, length(exactvalue); force_quadrature_rule = qf)
                println("EG = $EG | order = $order ($(qf.name), $(length(qf.w)) points) | error = $(quadvalue - exactvalue)")
                @test isapprox(quadvalue,exactvalue)
            end
        end
        println("")
    end



    ##################################################
    # TESTSET ORIENTATION/FACEDISCONTINUITY ASSEMBLY #
    ##################################################
    EGs = [Triangle2D,Parallelogram2D,Tetrahedron3D]

    @testset "FaceJumpAssembly" begin
        println("\n")
        println("=====================================")
        println("Testing Orientations/FaceJumpAssembly")
        println("=====================================")
        for EG in EGs
            maxerror = test_qpmatchup(testgrid(EG))
            println("EG = $EG | left-right-error = $maxerror")
            @test abs(maxerror) < 1e-14
            for disc in [Jump,Average]
                maxerror = test_disc_LF(testgrid(EG), disc)
                println("EG = $EG | disc = $disc | AP = LinearForm | error = $maxerror")
                @test abs(maxerror) < 1e-14
                maxerror = test_disc_BLF(testgrid(EG), disc)
                println("EG = $EG | disc = $disc | AP = BilinearForm | error = $maxerror")
                @test maximum(abs.(maxerror)) < 1e-13
                maxerror = test_disc_TLF(testgrid(EG), disc)
                println("EG = $EG | disc = $disc | AP = TrilinearForm | error = $maxerror")
                @test maximum(abs.(maxerror)) < 1e-13
            end
        end
    end

    ##########################################
    # TESTSET Finite Elements interpolations #
    ##########################################

    # list of FETypes that should be tested
    TestCatalog1D = [
                    H1P0{1},
                    H1P1{1}, 
                    H1P2{1,1}, 
                    H1P3{1,1}]
    ExpectedOrders1D = [0,1,2,3]
    TestCatalog2D = [
                    HCURLN0{2},
                    HDIVRT0{2},
                    HDIVBDM1{2},
                    H1P0{2},
                    H1P1{2}, 
                    H1CR{2},
                    H1MINI{2,2},
                    H1BR{2},
                    H1P2{2,2}, 
                    #H1P3{2,2}
                    ]
    ExpectedOrders2D = [0,0,1,0,1,1,1,1,2,3]
    TestCatalog3D = [
                    HCURLN0{3},
                    HDIVRT0{3},
                    HDIVBDM1{3},
                    H1P0{3},
                    H1P1{3}, 
                    H1CR{3},
                    H1MINI{3,3},
                    H1BR{3},
                    H1P2{3,3}]
    ExpectedOrders3D = [0,0,1,0,1,1,1,1,2]

    function test_interpolation(xgrid, FEType, order, broken::Bool = false)
        dim = dim_element(xgrid[CellGeometries][1])
        if dim == 1
            exact_function, exactvalue, exact_gradient, exact_hessian = exact_function1D(order)
        elseif dim == 2
            exact_function, exactvalue, exact_gradient, exact_hessian = exact_function2D(order)
        elseif dim == 3
            exact_function, exactvalue, exact_gradient, exact_hessian = exact_function3D(order)
        end

        # choose FE and generate FESpace
        FES = FESpace{FEType}(xgrid; broken = broken)
        AT = ON_CELLS

        # interpolate
        Solution = FEVector{Float64}("Interpolation",FES)
        interpolate!(Solution[1], exact_function)

        # check errors
        L2ErrorEvaluator = L2ErrorIntegrator(Float64, exact_function, Identity; AT = AT)
        H1ErrorEvaluator = L2ErrorIntegrator(Float64, exact_gradient, Gradient; AT = AT)
        H2ErrorEvaluator = L2ErrorIntegrator(Float64, exact_hessian, Hessian; AT = AT)
        error = zeros(Float64,3)
        error[1] = sqrt(evaluate(L2ErrorEvaluator,Solution[1]))
        if FEType <: AbstractH1FiniteElement
            error[2] = sqrt(evaluate(H1ErrorEvaluator,Solution[1]))
            error[3] = sqrt(evaluate(H2ErrorEvaluator,Solution[1]))
        end
        println("FEType = $FEType $(broken ? "broken" : "") $AT | ndofs = $(FES.ndofs) | order = $order | error = $error")
        @test sum(error) < tolerance
    end

    @testset "Interpolations" begin
        println("\n")
        println("============================")
        println("Testing Interpolations in 1D")
        println("============================")
        xgrid = testgrid(Edge1D)
        for n = 1 : length(TestCatalog1D)
            test_interpolation(xgrid, TestCatalog1D[n], ExpectedOrders1D[n])
            test_interpolation(xgrid, TestCatalog1D[n], ExpectedOrders1D[n], true)
        end
        println("\n")
        println("============================")
        println("Testing Interpolations in 2D")
        println("============================")
        for EG in [Triangle2D,Parallelogram2D]
            xgrid = testgrid(EG)
            for n = 1 : length(TestCatalog2D)
                test_interpolation(xgrid, TestCatalog2D[n], ExpectedOrders2D[n])
                test_interpolation(xgrid, TestCatalog2D[n], ExpectedOrders2D[n], true)
            end
        end
        println("\n")
        println("============================")
        println("Testing Interpolations in 3D")
        println("============================")
        for EG in [Tetrahedron3D]
            xgrid = testgrid(EG)
            for n = 1 : length(TestCatalog3D)
                test_interpolation(xgrid, TestCatalog3D[n], ExpectedOrders3D[n])
                test_interpolation(xgrid, TestCatalog3D[n], ExpectedOrders3D[n], true)
            end
        end
        println("")
    end

    #################################################
    # TESTSET Finite Elements L2-Bestapproximations #
    #################################################

    # list of FETypes that should be tested
    TestCatalog1D = [
                    H1P0{1},
                    H1P1{1}, 
                    H1P2{1,1}]
    ExpectedOrders1D = [0,1,2]
    TestCatalog2D = [
                    HCURLN0{2},
                    HDIVRT0{2},
                    HDIVBDM1{2},
                    H1P0{2},
                    H1P1{2}, 
                    H1CR{2},
                    H1MINI{2,2},
                    H1BR{2},
                    H1P2{2,2}]
    ExpectedOrders2D = [0,0,1,0,1,1,1,1,2]
    TestCatalog3D = [
                    HCURLN0{3},
                    HDIVRT0{3},
                    HDIVBDM1{3},
                    H1P0{3},
                    H1P1{3},
                    H1CR{3},
                    H1MINI{3,3},
                    H1BR{3},
                    H1P2{3,3}]
    ExpectedOrders3D = [0,0,1,0,1,1,1,1,2]

    function test_L2bestapproximation(xgrid, FEType, order, broken::Bool = false)
        dim = dim_element(xgrid[CellGeometries][1])
        if dim == 1
            exact_function, exactvalue = exact_function1D(order)
        elseif dim == 2
            exact_function, exactvalue = exact_function2D(order)
        elseif dim == 3
            exact_function, exactvalue = exact_function3D(order)
        end

        # Define Bestapproximation problem via PDETooles_PDEProtoTypes
        AT = ON_CELLS
        Problem = L2BestapproximationProblem(exact_function; bestapprox_boundary_regions = [], AT = AT)
        L2ErrorEvaluator = L2ErrorIntegrator(Float64, exact_function, Identity; AT = AT)

        # choose FE and generate FESpace
        FES = FESpace{FEType}(xgrid; broken = broken)

        # solve
        Solution = FEVector{Float64}("L2-Bestapproximation",FES)
        solve!(Solution, Problem)

        # check error
        error = sqrt(evaluate(L2ErrorEvaluator,Solution[1]))
        println("FEType = $FEType $(broken ? "broken" : "") | ndofs = $(FES.ndofs) | order = $order | error = $error")
        @test error < tolerance
    end

    @testset "L2-Bestapproximations" begin
        println("\n")
        println("===================================")
        println("Testing L2-Bestapproximations in 1D")
        println("===================================")
        xgrid = testgrid(Edge1D)
        for n = 1 : length(TestCatalog1D)
            test_L2bestapproximation(xgrid, TestCatalog1D[n], ExpectedOrders1D[n])
            test_L2bestapproximation(xgrid, TestCatalog1D[n], ExpectedOrders1D[n], true)
        end
        println("\n")
        println("===================================")
        println("Testing L2-Bestapproximations in 2D")
        println("===================================")
        xgrid = testgrid(Triangle2D, Parallelogram2D)
        for n = 1 : length(TestCatalog2D)
            test_L2bestapproximation(xgrid, TestCatalog2D[n], ExpectedOrders2D[n])
            test_L2bestapproximation(xgrid, TestCatalog2D[n], ExpectedOrders2D[n], true)
        end
        println("\n")
        println("===================================")
        println("Testing L2-Bestapproximations in 3D")
        println("===================================")
        xgrid = testgrid(Tetrahedron3D)
        for n = 1 : length(TestCatalog3D)
            test_L2bestapproximation(xgrid, TestCatalog3D[n], ExpectedOrders3D[n])
            test_L2bestapproximation(xgrid, TestCatalog3D[n], ExpectedOrders3D[n], true)
        end
        println("")
    end


    #################################################
    # TESTSET Finite Elements H1-Bestapproximations #
    #################################################

    # list of FETypes that should be tested
    TestCatalog1D = [
                    H1P1{1}, 
                    H1P2{1,1}]
    ExpectedOrders1D = [1,2]
    TestCatalog2D = [
                    H1P1{2}, 
                    H1CR{2},
                    H1MINI{2,2},
                    H1BR{2},
                    H1P2{2,2}]
    ExpectedOrders2D = [1,1,1,1,2]
    TestCatalog3D = [
                    H1P1{3},
                    H1MINI{3,3},
                    H1CR{3},
                    H1BR{3},
                    H1P2{3,3}]
    ExpectedOrders3D = [1,1,1,1,2]
    EG3D = [Tetrahedron3D]

    function test_H1bestapproximation(xgrid, FEType, order)
        dim = dim_element(xgrid[CellGeometries][1])
        if dim == 1
            exact_function, exactvalue, exact_function_gradient = exact_function1D(order)
        elseif dim == 2
            exact_function, exactvalue, exact_function_gradient = exact_function2D(order)
        elseif dim == 3
            exact_function, exactvalue, exact_function_gradient = exact_function3D(order)
        end

        # Define Bestapproximation problem via PDETooles_PDEProtoTypes
        Problem = H1BestapproximationProblem(exact_function_gradient, exact_function; bestapprox_boundary_regions = [1,2])
        L2ErrorEvaluator = L2ErrorIntegrator(Float64, exact_function, Identity)

        # choose FE and generate FESpace
        FES = FESpace{FEType}(xgrid)

        # solve
        Solution = FEVector{Float64}("L2-Bestapproximation",FES)
        solve!(Solution, Problem)

        # check error
        error = sqrt(evaluate(L2ErrorEvaluator,Solution[1]))
        println("FEType = $FEType | ndofs = $(FES.ndofs) | order = $order | error = $error")
        @test error < tolerance
    end

    @testset "H1-Bestapproximations" begin
        println("\n")
        println("===================================")
        println("Testing H1-Bestapproximations in 1D")
        println("===================================")
        xgrid = testgrid(Edge1D)
        for n = 1 : length(TestCatalog1D)
            test_H1bestapproximation(xgrid, TestCatalog1D[n], ExpectedOrders1D[n])
        end
        println("\n")
        println("===================================")
        println("Testing H1-Bestapproximations in 2D")
        println("===================================")
        xgrid = testgrid(Triangle2D, Parallelogram2D)
        for n = 1 : length(TestCatalog2D)
            test_H1bestapproximation(xgrid, TestCatalog2D[n], ExpectedOrders2D[n])
        end
        println("\n")
        println("===================================")
        println("Testing H1-Bestapproximations in 3D")
        println("===================================")
        for EG in EG3D
            xgrid = testgrid(EG)
            for n = 1 : length(TestCatalog3D)
                test_H1bestapproximation(xgrid, TestCatalog3D[n], ExpectedOrders3D[n])
            end
        end
        println("")
    end



    ###########################
    # TESTSET Stokes elements #
    ###########################


    function exact_functions_stokes2D(polyorder_velocity,polyorder_pressure)
        function exact_velocity!(result,x::Array{<:Real,1})
            result[1] = x[2]^polyorder_velocity + 1
            result[2] = x[1]^polyorder_velocity - 1
        end
        function exact_pressure!(result,x::Array{<:Real,1})
            result[1] = x[1]^polyorder_pressure + x[2]^polyorder_pressure - 2 // (polyorder_pressure+1)
        end
        function velo_gradient!(result,x::Array{<:Real,1})
            result[1] = 0
            result[2] = polyorder_velocity * x[2]^(polyorder_velocity-1)
            result[3] = polyorder_velocity * x[1]^(polyorder_velocity-1)
            result[4] = 0
        end
        function rhs!(result,x::Array{<:Real,1}) # = Delta u + grad p
            result[1] = 0
            result[2] = 0
            if polyorder_velocity > 1
                result[1] -= polyorder_velocity*(polyorder_velocity-1)*x[2]^(polyorder_velocity-2)
                result[2] -= polyorder_velocity*(polyorder_velocity-1)*x[1]^(polyorder_velocity-2)
            end
            if polyorder_pressure > 0
                result[1] += polyorder_pressure * x[1]^(polyorder_pressure-1)
                result[2] += polyorder_pressure * x[2]^(polyorder_pressure-1)
            end
        end
        exact_velocity = DataFunction(exact_velocity!, [2,2]; dependencies = "X", quadorder = polyorder_velocity)
        exact_pressure = DataFunction(exact_pressure!, [1,2]; dependencies = "X", quadorder = polyorder_pressure)
        exact_gradient = DataFunction(velo_gradient!, [4,2]; dependencies = "X", quadorder = polyorder_velocity - 1)
        rhs = DataFunction(rhs!, [2,2]; dependencies = "X", quadorder = max(0,polyorder_pressure - 1))
        return exact_velocity, exact_pressure, exact_gradient, rhs
    end

    function exact_functions_stokes3D(polyorder_velocity,polyorder_pressure)
        function exact_velocity!(result,x::Array{<:Real,1})
            result[1] = x[3]^polyorder_velocity + 1
            result[2] = x[1]^polyorder_velocity - 1
            result[3] = x[2]^polyorder_velocity
        end
        function exact_pressure!(result,x::Array{<:Real,1})
            result[1] = x[1]^polyorder_pressure + x[2]^polyorder_pressure + x[3]^polyorder_pressure  - 3 // (polyorder_pressure+1)
        end
        function velo_gradient!(result,x::Array{<:Real,1})
            result[1] = 0
            result[2] = 0
            result[3] = polyorder_velocity * x[3]^(polyorder_velocity-1)
            result[4] = polyorder_velocity * x[1]^(polyorder_velocity-1)
            result[5] = 0
            result[6] = 0
            result[7] = 0
            result[8] = polyorder_velocity * x[2]^(polyorder_velocity-1)
            result[9] = 0
        end
        function rhs!(result,x::Array{<:Real,1}) # = Delta u + grad p
            result[1] = 0
            result[2] = 0
            result[3] = 0
            if polyorder_velocity > 1
                result[1] -= polyorder_velocity*(polyorder_velocity-1)*x[3]^(polyorder_velocity-2)
                result[2] -= polyorder_velocity*(polyorder_velocity-1)*x[1]^(polyorder_velocity-2)
                result[3] -= polyorder_velocity*(polyorder_velocity-1)*x[2]^(polyorder_velocity-2)
            end
            if polyorder_pressure > 0
                result[1] += polyorder_pressure * x[1]^(polyorder_pressure-1)
                result[2] += polyorder_pressure * x[2]^(polyorder_pressure-1)
                result[3] += polyorder_pressure * x[3]^(polyorder_pressure-1)
            end
        end
        exact_velocity = DataFunction(exact_velocity!, [3,3]; dependencies = "X", quadorder = polyorder_velocity)
        exact_pressure = DataFunction(exact_pressure!, [1,3]; dependencies = "X", quadorder = polyorder_pressure)
        exact_gradient = DataFunction(velo_gradient!, [9,3]; dependencies = "X", quadorder = polyorder_velocity - 1)
        rhs = DataFunction(rhs!, [3,3]; dependencies = "X", quadorder = max(0,polyorder_pressure - 1))
        return exact_velocity, exact_pressure, exact_gradient, rhs
    end

    # list of FETypes that should be tested
    TestCatalogTriangle2D = [
                    [H1CR{2},H1P0{1},true],
                    [H1MINI{2,2},H1P1{1},false],
                    [H1BR{2},H1P0{1},true],
                    [H1P2{2,2},H1P1{1},false],
                    [H1P2B{2,2},H1P1{1},true]]
    TestCatalogParallelogram2D = [
                    [H1CR{2},H1P0{1},true],
                  #  [H1MINI{2,2},H1CR{1},false],
                    [H1BR{2},H1P0{1},true],
                    [H1P2{2,2},H1P1{1},false]]
    ExpectedOrdersTriangle2D = [[1,0],[1,1],[1,0],[2,1],[2,1]]
    ExpectedOrdersParallelogram2D = [[1,0],[1,0],[2,1],[2,1]]
    TestCatalog3D = [
                    [H1BR{3},H1P0{1},true],
                    [H1CR{3},H1P0{1},true],
                    [H1MINI{3,3},H1P1{1},false],
                    [H1P2{3,3},H1P1{1},false]
                    ]
    ExpectedOrders3D = [[1,0],[1,0],[1,1],[2,1]]


    function test_Stokes(xgrid, FETypes, orders, broken_p::Bool = false, RhsOp = Identity)
        dim = dim_element(xgrid[CellGeometries][1])
        if dim == 2
            exact_velocity, exact_pressure, exact_function_gradient, rhs = exact_functions_stokes2D(orders[1],orders[2])
        elseif dim == 3
            exact_velocity, exact_pressure, exact_function_gradient, rhs = exact_functions_stokes3D(orders[1],orders[2])
        end

        # Define Stokes problem via PDETooles_PDEProtoTypes
        Problem = IncompressibleNavierStokesProblem(dim; nonlinear = false)
        add_boundarydata!(Problem, 1, [1,2,3,4,5,6,7,8], BestapproxDirichletBoundary; data = exact_velocity)
        add_rhsdata!(Problem, 1, RhsOperator(RhsOp, [0], rhs))

        # choose FE and generate FESpace
        FES = [FESpace{FETypes[1]}(xgrid),FESpace{FETypes[2]}(xgrid; broken = broken_p)]

        # solve
        Solution = FEVector{Float64}("Stokes-Solution",FES)
        solve!(Solution, Problem)

        # check error
        L2ErrorEvaluatorV = L2ErrorIntegrator(Float64, exact_velocity, RhsOp)
        L2ErrorEvaluatorP = L2ErrorIntegrator(Float64, exact_pressure, Identity)
        errorV = sqrt(evaluate(L2ErrorEvaluatorV,Solution[1]))
        errorP = sqrt(evaluate(L2ErrorEvaluatorP,Solution[2]))
        if RhsOp == Identity
            # classical case
            println("EG = Triangle2D | FETypes = $(FETypes) | orders (V/P) = $orders | errorV = $errorV | errorP = $errorP")
            @test max(errorV,errorP) < tolerance
        else
            # p-robust case, only velocity error can be expected to be zero, as pressure is not in ansatz space
            println("EG = Triangle2D | FETypes = $(FETypes) | R = $RhsOp | orders (V/P) = $orders | errorV = $errorV ")
            @test errorV < tolerance
        end
    end

    @testset "Stokes-FEM" begin
        println("\n")
        println("=====================================")
        println("Testing Stokes elements on Triangle2D")
        println("=====================================")
        xgrid = testgrid(Triangle2D)
        for n = 1 : length(TestCatalogTriangle2D)
            test_Stokes(xgrid, TestCatalogTriangle2D[n][[1,2]], ExpectedOrdersTriangle2D[n], TestCatalogTriangle2D[n][3])
        end
        println("\n")
        println("==========================================")
        println("Testing Stokes elements on Parallelogram2D")
        println("==========================================")
        xgrid = uniform_refine(testgrid(Parallelogram2D),1)
        for n = 1 : length(TestCatalogParallelogram2D)
            test_Stokes(xgrid, TestCatalogParallelogram2D[n][[1,2]], ExpectedOrdersParallelogram2D[n], TestCatalogParallelogram2D[n][3])
        end
        println("\n")
        println("=============================")
        println("Testing Stokes elements in 3D")
        println("=============================")
        xgrid = testgrid(Tetrahedron3D)
        for n = 1 : length(TestCatalog3D)
            test_Stokes(xgrid, TestCatalog3D[n][[1,2]], ExpectedOrders3D[n], TestCatalog3D[n][3])
        end
        println("")
    end

    ####################################
    # TESTSET p-robust Stokes elements #
    ####################################

    # list of FETypes that should be tested
    TestCatalog2D = [
            [H1CR{2}, H1P0{1}, HDIVRT0{2}],
            [H1BR{2}, H1P0{1}, HDIVRT0{2}],
            [H1BR{2}, H1P0{1}, HDIVBDM1{2}]]
    ExpectedOrders2D = [[0,3],[0,3],[1,3]]
    TestCatalog3D = [
            [H1CR{3}, H1P0{1}, HDIVRT0{3}],
            [H1BR{3}, H1P0{1}, HDIVRT0{3}],
            [H1BR{3}, H1P0{1}, HDIVBDM1{3}]]
    ExpectedOrders3D = [[0,3],[0,3],[1,3]]

    @testset "Reconstruction-Operators" begin
    println("\n")
    println("======================================")
    println("Testing Reconstruction operators in 2D")
    println("======================================")
    xgrid = testgrid(Triangle2D, Parallelogram2D)
    for n = 1 : length(TestCatalog2D)
        test_Stokes(xgrid, TestCatalog2D[n][[1,2]], ExpectedOrders2D[n], true, ReconstructionIdentity{TestCatalog2D[n][3]})
    end
    println("\n")
    println("======================================")
    println("Testing Reconstruction operators in 3D")
    println("======================================")
    xgrid = testgrid(Tetrahedron3D)
    for n = 1 : length(TestCatalog3D)
        test_Stokes(xgrid, TestCatalog3D[n][[1,2]], ExpectedOrders3D[n], true, ReconstructionIdentity{TestCatalog3D[n][3]})
    end
    println("")
    end

end


function run_examples()
    println("\n")
    println("===================")
    println("Tests from Examples")
    println("===================")
    @testset "Examples" begin

        println("\n2D COMMUTING INTERPOLATORS")
        include("../examples/doc_2d_commutinginterpolators.jl")
        @test eval(Meta.parse("Example_2DCommutingInterpolators.test()")) < 1e-15

        println("\n3D COMMUTING INTERPOLATORS")
        include("../examples/doc_3d_commutinginterpolators.jl")
        @test eval(Meta.parse("Example_3DCommutingInterpolators.test()")) < 1e-15

        println("\n2D NONLINEAR POISSON")
        include("../examples/doc_2d_nonlin_poisson.jl")
        @test eval(Meta.parse("Example_2DNonlinearPoisson.test()")) < 1e-13

        println("\n2D NONLINEAR TIME_DEPENDENT POISSON")
        include("../examples/doc_2d_nonlin_poisson_timedependent.jl")
        @test eval(Meta.parse("Example_2DTransientNonlinPoisson.test()")) < 1e-15
        
        # tests the same reconstruction operator tests above, but let's keep it for now...
        println("\n2D PRESSURE_ROBUSTNESS")
        include("../examples/doc_2d_stokes_probust.jl")
        @test eval(Meta.parse("Example_2DPressureRobustness.test()")) < 1e-15
    end
end


function run_all_tests()
    begin
        run_basis_tests()
        run_examples()
    end
end

run_all_tests()