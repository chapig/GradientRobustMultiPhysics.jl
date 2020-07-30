##################
# L2GTransformer #
##################
#
# maps points of reference geometries to global world
# and is e.g. used by FEBasisEvaluator
#
# needs call of update! on entry of a new cell
# 
# eval! maps local xref on cell to global x (e.g. for evaluation of data functions)
# mapderiv! gives the derivative of the mapping (for computation of derivatives of basis functions)
# piola! gives the piola map (for flux-preserving transformation of Hdiv basis functions)

"""
    L2GTransformer

Transforms reference coordinates to global coordinates
"""
mutable struct L2GTransformer{T <: Real, EG <: AbstractElementGeometry, CS <: AbstractCoordinateSystem}
    citem::Int
    nonlinear::Bool # so that users know if derivatives of map change in every quadrature point of cell or not
    Coords::Array{T,2}
    Nodes::Union{VariableTargetAdjacency{Int32},Array{Int32,2}}
    ItemVolumes::Array{T,1}
    A::Matrix{T}
    b::Vector{T}
    C::Matrix{T} # cache for subcalculations that stay the same for each x (like adjugates)
end    

function L2GTransformer{T,EG,CS}(grid::ExtendableGrid, AT::Type{<:AbstractAssemblyType})  where {T <: Real, EG <: AbstractElementGeometry, CS <: AbstractCoordinateSystem}
    A = zeros(T,size(grid[Coordinates],1),dim_element(EG))
    b = zeros(T,size(grid[Coordinates],1))
    return L2GTransformer{T,EG,CS}(0,false,grid[Coordinates],grid[GridComponentNodes4AssemblyType(AT)],grid[GridComponentVolumes4AssemblyType(AT)],A,b,zeros(T,0,0))
end



function update!(T::L2GTransformer{<:Real,<:Edge1D,Cartesian1D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
    end    
end

function update!(T::L2GTransformer{<:Real,<:Edge1D,Cartesian2D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
    end    
end

function update!(T::L2GTransformer{<:Real,<:Triangle2D,Cartesian2D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[1,2] = T.Coords[1,T.Nodes[3,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
        T.A[2,2] = T.Coords[2,T.Nodes[3,item]] - T.b[2]
    end    
end

function update!(T::L2GTransformer{<:Real,<:Parallelogram2D,Cartesian2D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[1,2] = T.Coords[1,T.Nodes[4,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
        T.A[2,2] = T.Coords[2,T.Nodes[4,item]] - T.b[2]
    end    
end

function update!(T::L2GTransformer{<:Real,<:Triangle2D,Cartesian3D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.b[3] = T.Coords[3,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[1,2] = T.Coords[1,T.Nodes[3,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
        T.A[2,2] = T.Coords[2,T.Nodes[3,item]] - T.b[2]
        T.A[3,1] = T.Coords[3,T.Nodes[2,item]] - T.b[3]
        T.A[3,2] = T.Coords[3,T.Nodes[3,item]] - T.b[3]
    end    
end

function update!(T::L2GTransformer{<:Real,<:Parallelogram2D,Cartesian3D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.b[3] = T.Coords[3,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[1,2] = T.Coords[1,T.Nodes[4,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
        T.A[2,2] = T.Coords[2,T.Nodes[4,item]] - T.b[2]
        T.A[3,1] = T.Coords[3,T.Nodes[2,item]] - T.b[3]
        T.A[3,2] = T.Coords[3,T.Nodes[4,item]] - T.b[3]
    end    
end


function update!(T::L2GTransformer{<:Real,<:Union{Tetrahedron3D,Parallelepiped3D},Cartesian3D}, item::Int)
    if T.citem != item
        T.citem = item
        T.b[1] = T.Coords[1,T.Nodes[1,item]]
        T.b[2] = T.Coords[2,T.Nodes[1,item]]
        T.b[3] = T.Coords[3,T.Nodes[1,item]]
        T.A[1,1] = T.Coords[1,T.Nodes[2,item]] - T.b[1]
        T.A[1,2] = T.Coords[1,T.Nodes[3,item]] - T.b[1]
        T.A[1,3] = T.Coords[1,T.Nodes[4,item]] - T.b[1]
        T.A[2,1] = T.Coords[2,T.Nodes[2,item]] - T.b[2]
        T.A[2,2] = T.Coords[2,T.Nodes[3,item]] - T.b[2]
        T.A[2,3] = T.Coords[2,T.Nodes[4,item]] - T.b[2]
        T.A[3,1] = T.Coords[3,T.Nodes[2,item]] - T.b[3]
        T.A[3,2] = T.Coords[3,T.Nodes[3,item]] - T.b[3]
        T.A[3,3] = T.Coords[3,T.Nodes[4,item]] - T.b[3]

        # also cache the adjugate matrix = determinant of subblocks (for faster map_deriv!)
        if T.C == zeros(0,0)
            T.C = zeros(eltype(T.C),3,3)
        end

        T.C[1,1] =   T.A[2,2]*T.A[3,3] - T.A[2,3] * T.A[3,2]
        T.C[1,2] = -(T.A[2,1]*T.A[3,3] - T.A[2,3] * T.A[3,1])
        T.C[1,3] =   T.A[2,1]*T.A[3,2] - T.A[2,2] * T.A[3,1]
        T.C[2,1] = -(T.A[1,2]*T.A[3,3] - T.A[1,3] * T.A[3,2])
        T.C[2,2] =   T.A[1,1]*T.A[3,3] - T.A[1,3] * T.A[3,1]
        T.C[2,3] = -(T.A[1,1]*T.A[3,2] - T.A[1,2] * T.A[3,1])
        T.C[3,1] =   T.A[1,2]*T.A[2,3] - T.A[1,3] * T.A[2,2]
        T.C[3,2] = -(T.A[1,1]*T.A[2,3] - T.A[1,3] * T.A[2,1])
        T.C[3,3] =   T.A[1,1]*T.A[2,2] - T.A[1,2] * T.A[2,1]

    end    
end

function eval!(x::Vector, T::L2GTransformer{<:Real,<:Union{Triangle2D, Parallelogram2D},Cartesian2D}, xref)
    x[1] = T.A[1,1]*xref[1] + T.A[1,2]*xref[2] + T.b[1]
    x[2] = T.A[2,1]*xref[1] + T.A[2,2]*xref[2] + T.b[2]
end


function eval!(x::Vector, T::L2GTransformer{<:Real,<:Union{Triangle2D, Parallelogram2D},Cartesian3D}, xref)
    x[1] = T.A[1,1]*xref[1] + T.A[1,2]*xref[2] + T.b[1]
    x[2] = T.A[2,1]*xref[1] + T.A[2,2]*xref[2] + T.b[2]
    x[3] = T.A[3,1]*xref[1] + T.A[3,2]*xref[2] + T.b[3]
end


function eval!(x::Vector, T::L2GTransformer{<:Real,<:Union{Tetrahedron3D, Parallelepiped3D},Cartesian3D}, xref)
    x[1] = T.A[1,1]*xref[1] + T.A[1,2]*xref[2] + T.A[1,3]*xref[3] + T.b[1]
    x[2] = T.A[2,1]*xref[1] + T.A[2,2]*xref[2] + T.A[2,3]*xref[3] + T.b[2]
    x[3] = T.A[3,1]*xref[1] + T.A[3,2]*xref[2] + T.A[3,3]*xref[3] + T.b[3]
end


function eval!(x::Vector, T::L2GTransformer{<:Real,<:Edge1D,Cartesian1D}, xref)
    x[1] = T.A[1,1]*xref[1] + T.b[1]
end

function eval!(x::Vector, T::L2GTransformer{<:Real,<:Edge1D,Cartesian2D}, xref)
    x[1] = T.A[1,1]*xref[1] + T.b[1]
    x[2] = T.A[2,1]*xref[1] + T.b[2]
end

# EDGE1D/CARTESIAN1D map derivative
# x = a*xref + b
# Dxref/dx = a^{-1} = |E|^{-1}
function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Edge1D,Cartesian1D}, xref)
    # transposed inverse of A
    det = T.ItemVolumes[T.citem]
    M[1,1] = 1.0/det
    return det
end
# EDGE1D/CARTESIAN2D (tangential) map derivative
# x = A*xref + b
# Dxref/dx = A*tangent^{-1} = |E|^{-1}
function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Edge1D,Cartesian2D}, xref)
    # transposed inverse of A
    det = T.ItemVolumes[T.citem]
    M[1,1] = 1.0/det
    return det
end
# TRIANGLE2D/CARTESIAN2D map derivative
# x = A*xref + b
# Dxref/dx = A^{-T}
function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Triangle2D,Cartesian2D}, xref)
    # transposed inverse of A
    det = 2*T.ItemVolumes[T.citem]
    M[2,2] = T.A[1,1]/det
    M[2,1] = -T.A[1,2]/det
    M[1,2] = -T.A[2,1]/det
    M[1,1] = T.A[2,2]/det
    return det
end
# similar for parallelogram
function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Parallelogram2D,Cartesian2D}, xref)
    # transposed inverse of A
    det = T.ItemVolumes[T.citem]
    M[2,2] = T.A[1,1]/det
    M[2,1] = -T.A[1,2]/det
    M[1,2] = -T.A[2,1]/det
    M[1,1] = T.A[2,2]/det
    return det
end

function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Tetrahedron3D,Cartesian3D}, xref)
    # transposed inverse of A
    det = 6*T.ItemVolumes[T.citem]
    for j = 1 : 3, k = 1 : 3
        M[j,k] = T.C[j,k] / det
    end
    return det
end

function mapderiv!(M::Matrix, T::L2GTransformer{<:Real,<:Parallelepiped3D,Cartesian3D}, xref)
    # transposed inverse of A
    det = T.ItemVolumes[T.citem]
    for j = 1 : 3, k = 1 : 3
        M[j,k] = T.C[j,k] / det
    end
    return det
end

# TRIANGLE2D/CARTESIAN2D Piola map
# x = A*xref + b
# returns A
function piola!(M::Matrix, T::L2GTransformer{<:Real,<:Triangle2D,Cartesian2D}, xref)
    M[1,1] = T.A[1,1]
    M[1,2] = T.A[1,2]
    M[2,1] = T.A[2,1]
    M[2,2] = T.A[2,2]
    return 2*T.ItemVolumes[T.citem]
end
# similar for parallelogram
function piola!(M::Matrix, T::L2GTransformer{<:Real,<:Parallelogram2D,Cartesian2D}, xref)
    M[1,1] = T.A[1,1]
    M[1,2] = T.A[1,2]
    M[2,1] = T.A[2,1]
    M[2,2] = T.A[2,2]
    return T.ItemVolumes[T.citem]
end