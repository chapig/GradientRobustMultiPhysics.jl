
# type to steer when a PDE block is (re)assembled
abstract type AbstractAssemblyTrigger end
abstract type AssemblyFinal <: AbstractAssemblyTrigger end   # is only assembled after solving
abstract type AssemblyAlways <: AbstractAssemblyTrigger end     # is always (re)assembled
    abstract type AssemblyEachTimeStep <: AssemblyAlways end     # is (re)assembled in each timestep
        abstract type AssemblyInitial <: AssemblyEachTimeStep end    # is only assembled in initial assembly
            abstract type AssemblyNever <: AssemblyInitial end   # is never assembled



#######################
# AbstractPDEOperator #
#######################
#
# to describe operators in the (weak form of the) PDE
#
# some intermediate layer that knows nothing of the FE discretisatons
# but triggers certain AssemblyPatterns/AbstractActions when called for assembly!
#
# USER-DEFINED ABSTRACTPDEOPERATORS
# might be included if they implement the following interfaces
#
#   (1) to specify what is assembled into the corressponding MatrixBlock:
#       assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::AbstractPDEOperatorLHS)
#       assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::AbstractPDEOperatorRHS)
#
#   (2) to allow SolverConfig to check if operator is nonlinear, timedependent:
#       Bool, Bool = check_PDEoperator(O::AbstractPDEOperator)
# 


abstract type AbstractPDEOperator end
abstract type NoConnection <: AbstractPDEOperator end # => empy block in matrix
abstract type AbstractPDEOperatorRHS  <: AbstractPDEOperator end # can be used in RHS (and LHS when one component is fixed)
abstract type AbstractPDEOperatorLHS  <: AbstractPDEOperator end # can be used in RHS (and LHS when one component is fixed)


"""
$(TYPEDEF)

puts _value_ on the diagonal entries of the cell dofs within given _regions_

if _onlyz_ == true only values that are zero are changed

can only be applied in PDE LHS
"""
struct DiagonalOperator <: AbstractPDEOperatorLHS
    name::String
    value::Real
    onlyz::Bool
    regions::Array{Int,1}
end
function DiagonalOperator(value::Real = 1.0, onlynz::Bool = true; regions::Array{Int,1} = [0])
    return DiagonalOperator("Diag($value)",value, onlynz, regions)
end


"""
$(TYPEDEF)

copies entries from TargetVector to rhs block

can only be applied in PDE RHS
"""
struct CopyOperator <: AbstractPDEOperatorRHS
    name::String
    copy_from::Int
    factor::Real
end
function CopyOperator(copy_from, factor)
    return CopyOperator("CopyOperator",copy_from, factor)
end

"""
$(TYPEDEF)

abstract bilinearform operator that assembles
- b(u,v) = int_regions action(operator1(u)) * operator2(v) if apply_action_to = 1
- b(u,v) = int_regions operator1(u) * action(operator2(v)) if apply_action_to = 2

can only be applied in PDE LHS
"""
mutable struct AbstractBilinearForm{AT<:AbstractAssemblyType} <: AbstractPDEOperatorLHS
    name::String
    operator1::Type{<:AbstractFunctionOperator}
    operator2::Type{<:AbstractFunctionOperator}
    action::AbstractAction
    apply_action_to::Int
    regions::Array{Int,1}
    transposed_assembly::Bool
    store_operator::Bool                    # should the matrix repsentation of the operator be stored?
    storage::AbstractArray{Float64,2}  # matrix can be stored here to allow for fast matmul operations in iterative settings
end
function AbstractBilinearForm(name, operator1,operator2, action; apply_action_to = 1, regions::Array{Int,1} = [0], transposed_assembly::Bool = false)
    return AbstractBilinearForm{AssemblyTypeCELL}(name,operator1, operator2, action, apply_action_to, regions,transposed_assembly,false,zeros(Float64,0,0))
end
function AbstractBilinearForm(operator1,operator2; apply_action_to = 1, regions::Array{Int,1} = [0])
    return AbstractBilinearForm("$operator1 x $operator2",operator1, operator2, DoNotChangeAction(1); apply_action_to = apply_action_to, regions = regions)
end
function LaplaceOperator(diffusion::Real = 1.0, xdim::Int = 2, ncomponents::Int = 1; gradient_operator = Gradient, regions::Array{Int,1} = [0])
    return AbstractBilinearForm("Laplacian",gradient_operator, gradient_operator, MultiplyScalarAction(diffusion, ncomponents*xdim); regions = regions)
end
# todo
# here a general connection to arbitrary tensors C_ijkl (encencodedoded as an action) is possible in future
function HookStiffnessOperator1D(mu::Real; regions::Array{Int,1} = [0], gradient_operator = TangentialGradient)
    function tensor_apply_1d(result, input)
        # just Hook law like a spring where mu is the elasticity modulus
        result[1] = mu*input[1]
    end   
    action = FunctionAction(tensor_apply_1d, 1, 1)
    return AbstractBilinearForm("Hookian1D",gradient_operator, gradient_operator, action; regions = regions)
end
function HookStiffnessOperator2D(mu::Real, lambda::Real; regions::Array{Int,1} = [0], gradient_operator = SymmetricGradient)
    function tensor_apply_2d(result, input)
        # compute sigma_ij = C_ijkl eps_kl
        # where input = [eps_11,eps_12,eps_21] is the symmetric gradient in Voigt notation
        # and result = [sigma_11,sigma_12,sigma_21] is Voigt representation of sigma_11
        # the tensor C is just a 3x3 matrix
        result[1] = (lambda + 2*mu)*input[1] + lambda*input[2]
        result[2] = (lambda + 2*mu)*input[2] + lambda*input[1]
        result[3] = mu*input[3]
    end   
    action = FunctionAction(tensor_apply_2d, 3, 2)
    return AbstractBilinearForm("Hookian2D",gradient_operator, gradient_operator, action; regions = regions)
end
function ReactionOperator(action::AbstractAction; apply_action_to = 1, identity_operator = Identity, regions::Array{Int,1} = [0])
    return AbstractBilinearForm("Reaction",identity_operator, identity_operator, action; apply_action_to = apply_action_to, regions = regions)
end
function ConvectionOperator(beta::Function, xdim::Int, ncomponents::Int; bonus_quadorder::Int = 0, testfunction_operator::Type{<:AbstractFunctionOperator} = Identity, regions::Array{Int,1} = [0])
    function convection_function_func() # dot(convection!, input=Gradient)
        convection_vector = zeros(Float64,xdim)
        function closure(result, input, x)
            # evaluate beta
            beta(convection_vector,x)
            # compute (beta*grad)u
            for j = 1 : ncomponents
                result[j] = 0.0
                for k = 1 : xdim
                    result[j] += convection_vector[k]*input[(j-1)*xdim+k]
                end
            end
        end    
    end    
    convection_action = XFunctionAction(convection_function_func(), ncomponents, xdim; bonus_quadorder = bonus_quadorder)
    return AbstractBilinearForm("(a(=XFunction) * Gradient) u * v", Gradient,testfunction_operator, convection_action; regions = regions, transposed_assembly = true)
end




"""
$(TYPEDEF)

considers the second argument to be a Lagrange multiplier for operator(first argument) = 0,
automatically triggers copy of transposed operator in transposed block, hence only needs to be assigned and assembled once!

can only be applied in PDE LHS
"""
struct LagrangeMultiplier <: AbstractPDEOperatorLHS
    name::String
    operator::Type{<:AbstractFunctionOperator} # e.g. Divergence, automatically aligns with transposed block
end
function LagrangeMultiplier(operator::Type{<:AbstractFunctionOperator})
    return LagrangeMultiplier("LagrangeMultiplier($operator)",operator)
end



"""
$(TYPEDEF)

abstract trilinearform operator that assembles
- c(a,u,v) = int_regions action(operator1(a) * operator2(u))*operator3(v)

where a is one of the other unknowns of the PDEsystem

can only be applied in PDE LHS
"""
mutable struct AbstractTrilinearForm{AT<:AbstractAssemblyType} <: AbstractPDEOperatorLHS
    name::String
    operator1::Type{<:AbstractFunctionOperator}
    operator2::Type{<:AbstractFunctionOperator}
    operator3::Type{<:AbstractFunctionOperator}
    a_from::Int
    action::AbstractAction # is applied to argument 1 and 2, i.e input consists of operator1(a),operator2(u)
    regions::Array{Int,1}
    transposed_assembly::Bool
end
function ConvectionOperator(beta::Int, xdim::Int, ncomponents::Int; testfunction_operator::Type{<:AbstractFunctionOperator} = Identity, regions::Array{Int,1} = [0])
    # action input consists of two inputs
    # input[1:ncomponents] = operator1(a)
    # input[ncomponents+1:length(input)] = u
    function convection_function_fe()
        function closure(result, input)
            for j = 1 : ncomponents
                result[j] = 0.0
                for k = 1 : xdim
                    result[j] += input[k]*input[ncomponents+(j-1)*xdim+k]
                end
            end
        end    
    end    
    convection_action = FunctionAction(convection_function_fe(), ncomponents)
    return AbstractTrilinearForm{AssemblyTypeCELL}("(a(=unknown $beta) * Gradient) u * v",Identity,Gradient,testfunction_operator,beta ,convection_action, regions, true)
end

"""
$(TYPEDEF)

right-hand side operator

can only be applied in PDE RHS
"""
struct RhsOperator{AT<:AbstractAssemblyType} <: AbstractPDEOperatorRHS
    rhsfunction::Function
    testfunction_operator::Type{<:AbstractFunctionOperator}
    timedependent::Bool
    regions::Array{Int,1}
    xdim:: Int
    ncomponents:: Int
    bonus_quadorder:: Int
end

function RhsOperator(
    operator::Type{<:AbstractFunctionOperator},
    regions::Array{Int,1},
    rhsfunction::Function,
    xdim::Int,
    ncomponents::Int = 1;
    bonus_quadorder::Int = 0,
    on_boundary::Bool = false,
    timedependent::Bool = false)
    if on_boundary == true
        return RhsOperator{AssemblyTypeBFACE}(rhsfunction, operator, timedependent, regions, xdim, ncomponents, bonus_quadorder)
    else
        return RhsOperator{AssemblyTypeCELL}(rhsfunction, operator, timedependent, regions, xdim, ncomponents, bonus_quadorder)
    end
end


"""
$(TYPEDEF)

evaluation of a bilinearform where the second argument is fixed by given FEVectorBlock

can only be applied in PDE RHS
"""
struct BLFeval <: AbstractPDEOperatorRHS
    BLF::AbstractBilinearForm
    Data::FEVectorBlock
    factor::Real
end


"""
$(TYPEDEF)

evaluation of a trilinearform where thefirst and  second argument is fixed by given FEVectorBlocks

can only be applied in PDE RHS
"""
struct TLFeval <: AbstractPDEOperatorRHS
    TLF::AbstractTrilinearForm
    Data1::FEVectorBlock
    Data2::FEVectorBlock
    factor::Real
end


##################################
### FVUpwindDivergenceOperator ###
##################################
#
# finite-volume upwind divergence div_upw(beta*rho)
#
# assumes rho is constant on each cell
# 
# (1) calculate normalfluxes from component at _beta_from_
# (2) compute upwind divergence on each cell and put coefficient in matrix
#           div_upw(beta*rho)|_T = sum_{F face of T} normalflux(F) * rho(F)
#
#           where rho(F) is the rho in upwind direction 
#
#     and put it into P0xP0 matrix block like this:
#
#           Loop over cell, face of cell
#
#               other_cell = other face neighbour cell
#               if flux := normalflux(F_j) * CellFaceSigns[face,cell] > 0
#                   A(cell,cell) += flux
#                   A(other_cell,cell) -= flux
#               else
#                   A(other_cell,other_cell) -= flux
#                   A(cell,other_cell) += flux
#                   
# see coressponding assemble! routine

mutable struct FVUpwindDivergenceOperator <: AbstractPDEOperatorLHS
    name::String
    beta_from::Int                   # component that determines
    fluxes::Array{Float64,2}         # saves normalfluxes of beta here
end
function FVUpwindDivergenceOperator(beta_from::Int)
    @assert beta_from > 0
    fluxes = zeros(Float64,0,1)
    return FVUpwindDivergenceOperator("FVUpwindDivergence",beta_from,fluxes)
end
function check_PDEoperator(O::RhsOperator)
    return false, O.timedependent
end


################ ASSEMBLY SPECIFICATIONS ################



# check if operator causes nonlinearity or time-dependence
function check_PDEoperator(O::AbstractPDEOperator)
    return false, false
end
function check_PDEoperator(O::AbstractTrilinearForm)
    return true, false
end
function check_PDEoperator(O::FVUpwindDivergenceOperator)
    return O.beta_from != 0, false
end
function check_PDEoperator(O::CopyOperator)
    return true, true
end

# check if operator also depends on arg (additional to the argument relative to position in PDEDescription)
function check_dependency(O::AbstractPDEOperator, arg::Int)
    return false
end

function check_dependency(O::FVUpwindDivergenceOperator, arg::Int)
    return O.beta_from == arg
end

function check_dependency(O::AbstractTrilinearForm, arg::Int)
    return O.a_from == arg
end



function assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::DiagonalOperator; time::Real = 0, verbosity::Int = 0)
    FE1 = A.FESX
    FE2 = A.FESY
    @assert FE1 == FE2
    xCellDofs = FE1.CellDofs
    xCellRegions = FE1.xgrid[CellRegions]
    ncells = num_sources(xCellDofs)
    dof::Int = 0
    for item = 1 : ncells
        for r = 1 : length(O.regions) 
            # check if item region is in regions
            if xCellRegions[item] == O.regions[r] || O.regions[r] == 0
                for k = 1 : num_targets(xCellDofs,item)
                    dof = xCellDofs[k,item]
                    if O.onlyz == true
                        if A[dof,dof] == 0
                            A[dof,dof] = O.value
                        end
                    else
                        A[dof,dof] = O.value
                    end    
                end
            end
        end
    end
end


function assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::FVUpwindDivergenceOperator; time::Real = 0, verbosity::Int = 0)
    FE1 = A.FESX
    FE2 = A.FESY
    @assert FE1 == FE2
    xFaceNodes = FE1.xgrid[FaceNodes]
    xFaceNormals = FE1.xgrid[FaceNormals]
    xFaceCells = FE1.xgrid[FaceCells]
    xFaceVolumes = FE1.xgrid[FaceVolumes]
    xCellFaces = FE1.xgrid[CellFaces]
    xCellFaceSigns = FE1.xgrid[CellFaceSigns]
    nfaces = num_sources(xFaceNodes)
    ncells = num_sources(xCellFaceSigns)
    nnodes = num_sources(FE1.xgrid[Coordinates])
    
    # ensure that flux field is long enough
    if length(O.fluxes) < nfaces
        O.fluxes = zeros(Float64,nfaces,1)
    end

    # compute normal fluxes of component beta
    c = O.beta_from
    fill!(O.fluxes,0)
    fluxIntegrator = ItemIntegrator{Float64,AssemblyTypeFACE}(NormalFlux, DoNotChangeAction(1), [0])
    evaluate!(O.fluxes,fluxIntegrator,CurrentSolution[c]; verbosity = verbosity - 1)

    nfaces4cell = 0
    face = 0
    flux = 0.0
    other_cell = 0
    for cell = 1 : ncells
        nfaces4cell = num_targets(xCellFaces,cell)
        for cf = 1 : nfaces4cell
            face = xCellFaces[cf,cell]
            other_cell = xFaceCells[1,face]
            if other_cell == cell
                other_cell = xFaceCells[2,face]
            end
            flux = - O.fluxes[face] * xCellFaceSigns[cf,cell]
            if (other_cell > 0) 
                flux *= 1 // 2
            end       
            if flux > 0
                A[cell,cell] += flux
                if other_cell > 0
                    A[other_cell,cell] -= flux
                end    
            else   
                if other_cell > 0
                    A[other_cell,other_cell] -= flux
                    A[cell,other_cell] += flux
                end 
            end
        end
    end
end



function update_storage!(O::AbstractBilinearForm{AT}, CurrentSolution::FEVector, j::Int, k::Int; factor::Real = 1, time::Real = 0, verbosity::Int = 0) where {AT<:AbstractAssemblyType}

    # ensure that storage is large_enough
    FE1 = CurrentSolution[j].FES
    FE2 = CurrentSolution[k].FES
    O.storage = ExtendableSparseMatrix{Float64,Int32}(FE1.ndofs,FE2.ndofs)

    if FE1 == FE2 && O.operator1 == O.operator2
        BLF = SymmetricBilinearForm(Float64, AT, FE1, O.operator1, O.action; regions = O.regions)    
    else
        BLF = BilinearForm(Float64, AT, FE1, FE2, O.operator1, O.operator2, O.action; regions = O.regions)    
    end

    assemble!(O.storage, BLF; apply_action_to = O.apply_action_to, factor = factor, verbosity = verbosity)
    flush!(O.storage)
end

function assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::AbstractBilinearForm{AT}; factor::Real = 1, time::Real = 0, verbosity::Int = 0) where {AT<:AbstractAssemblyType}
    if O.store_operator == true
        addblock!(A,O.storage; factor = factor)
    else
        FE1 = A.FESX
        FE2 = A.FESY
        if FE1 == FE2 && O.operator1 == O.operator2
            BLF = SymmetricBilinearForm(Float64, AT, FE1, O.operator1, O.action; regions = O.regions)    
        else
            BLF = BilinearForm(Float64, AT, FE1, FE2, O.operator1, O.operator2, O.action; regions = O.regions)    
        end
        assemble!(A, BLF; apply_action_to = O.apply_action_to, factor = factor, verbosity = verbosity, transposed_assembly = O.transposed_assembly)
    end
end


function assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::AbstractBilinearForm{AT}; factor::Real = 1, time::Real = 0, verbosity::Int = 0, fixed_component::Int = 0) where {AT<:AbstractAssemblyType}
    if O.store_operator == true
        addblock_matmul!(b,O.storage,CurrentSolution[fixed_component]; factor = factor)
    else
        FE1 = b.FES
        FE2 = CurrentSolution[fixed_component].FES
        if FE1 == FE2 && O.operator1 == O.operator2
            BLF = SymmetricBilinearForm(Float64, AT, FE1, O.operator1, O.action; regions = O.regions)    
        else
            BLF = BilinearForm(Float64, AT, FE1, FE2, O.operator1, O.operator2, O.action; regions = O.regions)    
        end
        assemble!(b, CurrentSolution[fixed_component], BLF; apply_action_to = O.apply_action_to, factor = factor, verbosity = verbosity)
    end
end



function assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::TLFeval; factor::Real = 1, time::Real = 0, verbosity::Int = 0)
    FE1 = O.Data1.FES
    FE2 = O.Data2.FES
    FE3 = b.FES
    TLF = TrilinearForm(Float64, AssemblyTypeCELL, FE1, FE2, FE3, O.TLF.operator1, O.TLF.operator2, O.TLF.operator3, O.TLF.action; regions = O.TLF.regions)  
    assemble!(b, O.Data1, O.Data2, TLF; factor = factor * O.factor, verbosity = verbosity)
end

function assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::BLFeval; factor::Real = 1, time::Real = 0, verbosity::Int = 0)
    if O.BLF.store_operator == true
        addblock_matmul!(b,O.BLF.storage,O.Data; factor = factor)
    else
        FE1 = b.FES
        FE2 = O.Data.FES
        if FE1 == FE2 && O.BLF.operator1 == O.BLF.operator2
            BLF = SymmetricBilinearForm(Float64, AssemblyTypeCELL, FE1, O.BLF.operator1, O.BLF.action; regions = O.BLF.regions)    
        else
            BLF = BilinearForm(Float64, AssemblyTypeCELL, FE1, FE2, O.BLF.operator1, O.BLF.operator2, O.BLF.action; regions = O.BLF.regions)    
        end
        assemble!(b, O.Data, BLF; apply_action_to = O.BLF.apply_action_to, factor = factor * O.factor, verbosity = verbosity)
    end
end

function assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::AbstractTrilinearForm; time::Real = 0, verbosity::Int = 0)
    FE1 = CurrentSolution[O.a_from].FES
    FE2 = A.FESX
    FE3 = A.FESY
    TLF = TrilinearForm(Float64, AssemblyTypeCELL, FE1, FE2, FE3, O.operator1, O.operator2, O.operator3, O.action; regions = O.regions)  
    assemble!(A, CurrentSolution[O.a_from], TLF; verbosity = verbosity, transposed_assembly = O.transposed_assembly)
end

function assemble!(A::FEMatrixBlock, CurrentSolution::FEVector, O::LagrangeMultiplier; time::Real = 0, verbosity::Int = 0, At::FEMatrixBlock)
    FE1 = A.FESX
    FE2 = A.FESY
    @assert At.FESX == FE2
    @assert At.FESY == FE1
    DivPressure = BilinearForm(Float64, AssemblyTypeCELL, FE1, FE2, O.operator, Identity, MultiplyScalarAction(-1.0,1))   
    assemble!(A, DivPressure; verbosity = verbosity, transpose_copy = At)
end

function assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::RhsOperator{AT}; factor::Real = 1, time::Real = 0, verbosity::Int = 0) where {AT<:AbstractAssemblyType}
    FE = b.FES
    if O.timedependent
        function rhs_function_td() # result = F(v) = f*operator(v) = f*input
            temp = zeros(Float64,O.ncomponents)
            function closure(result,input,x)
                O.rhsfunction(temp,x,time)
                result[1] = 0
                for j = 1 : O.ncomponents
                    result[1] += temp[j]*input[j] 
                end
            end
        end    
        action = XFunctionAction(rhs_function_td(),1,O.xdim; bonus_quadorder = O.bonus_quadorder)
    else
        function rhs_function() # result = F(v) = f*operator(v) = f*input
            temp = zeros(Float64,O.ncomponents)
            function closure(result,input,x)
                O.rhsfunction(temp,x)
                result[1] = 0
                for j = 1 : O.ncomponents
                    result[1] += temp[j]*input[j] 
                end
            end
        end    
        action = XFunctionAction(rhs_function(),1,O.xdim; bonus_quadorder = O.bonus_quadorder)
    end
    RHS = LinearForm(Float64,AT, FE, O.testfunction_operator, action; regions = O.regions)
    assemble!(b, RHS; factor = factor, verbosity = verbosity)
end


function assemble!(b::FEVectorBlock, CurrentSolution::FEVector, O::CopyOperator; time::Real = 0, verbosity::Int = 0) 
    for j = 1 : length(b)
        b[j] = CurrentSolution[O.copy_from][j] * O.factor
    end
end
