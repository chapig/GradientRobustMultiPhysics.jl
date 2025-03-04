
"""
````
abstract type H1P3{ncomponents,edim} <: AbstractH1FiniteElement where {ncomponents<:Int,edim<:Int}
````

Continuous piecewise third-order polynomials.

allowed ElementGeometries:
- Edge1D (cubic polynomials)
"""
abstract type H1P3{ncomponents,edim} <: AbstractH1FiniteElement where {ncomponents<:Int,edim<:Int} end

function Base.show(io::Core.IO, FEType::Type{<:H1P3})
    print(io,"H1P3{$(FEType.parameters[1]),$(FEType.parameters[2])}")
end

get_ncomponents(FEType::Type{<:H1P3}) = FEType.parameters[1]
get_edim(FEType::Type{<:H1P3}) = FEType.parameters[2]

get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:H1P3}, EG::Type{<:Union{AbstractElementGeometry1D, Triangle2D, Tetrahedron3D}}) = FEType.parameters[1]*Int(factorial(FEType.parameters[2]+2)/(6*factorial(FEType.parameters[2]-1)))
get_ndofs(::Type{<:ON_CELLS},FEType::Type{<:H1P3}, EG::Type{<:Union{AbstractElementGeometry1D, Triangle2D, Tetrahedron3D}}) = FEType.parameters[1]*Int(factorial(FEType.parameters[2]+3)/(6*factorial(FEType.parameters[2])))

get_polynomialorder(::Type{<:H1P3}, ::Type{<:Edge1D}) = 3;
get_polynomialorder(::Type{<:H1P3}, ::Type{<:Triangle2D}) = 3;
get_polynomialorder(::Type{<:H1P3}, ::Type{<:Tetrahedron3D}) = 3;

get_dofmap_pattern(FEType::Type{<:H1P3}, ::Type{CellDofs}, EG::Type{<:AbstractElementGeometry1D}) = "N1I2"
get_dofmap_pattern(FEType::Type{<:H1P3}, ::Type{CellDofs}, EG::Type{<:AbstractElementGeometry2D}) = "N1F2I1"
get_dofmap_pattern(FEType::Type{<:H1P3}, ::Union{Type{FaceDofs},Type{BFaceDofs}}, EG::Type{<:AbstractElementGeometry0D}) = "N1"
get_dofmap_pattern(FEType::Type{<:H1P3}, ::Union{Type{FaceDofs},Type{BFaceDofs}}, EG::Type{<:AbstractElementGeometry1D}) = "N1I2"

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{AT_NODES}, exact_function!; items = [], bonus_quadorder::Int = 0, time = 0) where {FEType <: H1P3}
    edim = get_edim(FEType)
    coffset = size(FE.xgrid[Coordinates],2)
    if edim == 1
        coffset += 2*num_sources(FE.xgrid[CellNodes])
    elseif edim == 2
        coffset += 2*num_sources(FE.xgrid[FaceNodes]) + num_sources(FE.xgrid[CellNodes])
    elseif edim == 3
        coffset += 2*num_sources(FE.xgrid[EdgeNodes]) + num_sources(FE.xgrid[FaceNodes]) + num_sources(FE.xgrid[CellNodes])
    end

    point_evaluation!(Target, FE, AT_NODES, exact_function!; items = items, component_offset = coffset, time = time)
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_EDGES}, exact_function!; items = [], bonus_quadorder::Int = 0, time = 0) where {FEType <: H1P3}
    edim = get_edim(FEType)
    if edim == 3
        # delegate edge nodes to node interpolation
        subitems = slice(FE.xgrid[EdgeNodes], items)
        interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)

        # perform edge mean interpolation
        ensure_edge_moments!(Target, FE, ON_EDGES, exact_function!; order = 1, items = items, time = time)
    end
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_FACES}, exact_function!; items = [], bonus_quadorder::Int = 0, time = 0) where {FEType <: H1P3}
    edim = get_edim(FEType)
    if edim == 2
        # delegate face nodes to node interpolation
        subitems = slice(FE.xgrid[FaceNodes], items)
        interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)

        # perform face mean interpolation
        ensure_edge_moments!(Target, FE, ON_FACES, exact_function!; items = items, order = 1, time = time)
    elseif edim == 3
        # delegate face edges to edge interpolation
        subitems = slice(FE.xgrid[FaceEdges], items)
        interpolate!(Target, FE, ON_EDGES, exact_function!; items = subitems, time = time)
    elseif edim == 1
        # delegate face nodes to node interpolation
        subitems = slice(FE.xgrid[FaceNodes], items)
        interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)
    end
end


function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_CELLS}, exact_function!; items = [], bonus_quadorder::Int = 0, time = 0) where {FEType <: H1P3}
    edim = get_edim(FEType)
    ncells = num_sources(FE.xgrid[CellNodes])
    if edim == 2
        # delegate cell faces to face interpolation
        subitems = slice(FE.xgrid[CellFaces], items)
        interpolate!(Target, FE, ON_FACES, exact_function!; items = subitems, time = time)
        
        # fix cell bubble value by preserving integral mean
        ensure_cell_moments!(Target, FE, exact_function!; facedofs = 2, items = items, time = time)
    elseif edim == 3
        # delegate cell edges to edge interpolation
        subitems = slice(FE.xgrid[CellEdges], items)
        interpolate!(Target, FE, ON_EDGES, exact_function!; items = subitems, time = time)

        # fix cell bubble value by preserving integral mean
        ensure_cell_moments!(Target, FE, exact_function!; facedofs = 2, edgedofs = 2, items = items, time = time)
    elseif edim == 1
        # delegate cell nodes to node interpolation
        subitems = slice(FE.xgrid[CellNodes], items)
        interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)

        # preserve cell integral
        ensure_edge_moments!(Target, FE, ON_CELLS, exact_function!; order = 1, items = items, time = time)
    end
end


function get_basis(::Type{<:AbstractAssemblyType},::Type{<:H1P3}, ::Type{<:Vertex0D})
    ncomponents = get_ncomponents(FEType)
    function closure(refbasis,xref)
        for k = 1 : ncomponents
            refbasis[k,k] = 1
        end
    end
end

function get_basis(::Type{<:AbstractAssemblyType},FEType::Type{<:H1P3}, ::Type{<:Edge1D})
    ncomponents = get_ncomponents(FEType)
    function closure(refbasis, xref)
        temp = 1 - xref[1]
        for k = 1 : ncomponents
            refbasis[4*k-3,k] = 9 // 2 * temp * (temp - 1//3) * (temp - 2//3)            # node 1 (scaled such that 1 at x = 0)
            refbasis[4*k-2,k] = 9 // 2 * xref[1] * (xref[1] - 1//3) * (xref[1] - 2//3)   # node 2 (scaled such that 1 at x = 1)
            refbasis[4*k-1,k] = -27/2*xref[1]*temp*(xref[1] - 2//3)                          # face 1 (scaled such that 1 at x = 1//3)
            refbasis[4*k,k] = 27//2*xref[1]*temp*(xref[1] - 1//3)                            # face 2 (scaled such that 1 at x = 2//3)
        end
    end
end

function get_basis(::Type{<:AbstractAssemblyType},FEType::Type{<:H1P3}, ::Type{<:Triangle2D})
    ncomponents = get_ncomponents(FEType)
    function closure(refbasis, xref)
        temp = 1 - xref[1] - xref[2]
        for k = 1 : ncomponents
            refbasis[10*k-9,k] = 9 // 2 * temp * (temp - 1//3) * (temp - 2//3)            # node 1
            refbasis[10*k-8,k] = 9 // 2 * xref[1] * (xref[1] - 1//3) * (xref[1] - 2//3)   # node 2
            refbasis[10*k-7,k] = 9 // 2 * xref[2] * (xref[2] - 1//3) * (xref[2] - 2//3)   # node 3
            refbasis[10*k-6,k] = -27/2*xref[1]*temp*(xref[1] - 2//3)                      # face 1.1
            refbasis[10*k-5,k] = 27//2*xref[1]*temp*(xref[1] - 1//3)                      # face 1.2
            refbasis[10*k-4,k] = -27/2*xref[2]*xref[1]*(xref[2] - 2//3)                   # face 2.1
            refbasis[10*k-3,k] = 27//2*xref[2]*xref[1]*(xref[2] - 1//3)                   # face 2.2
            refbasis[10*k-2,k] = -27/2*temp*xref[2]*(temp - 2//3)                         # face 3.1
            refbasis[10*k-1,k] = 27//2*temp*xref[2]*(temp - 1//3)                         # face 3.2
            refbasis[10*k,k] = 60*xref[1]*xref[2]*temp                                    # cell (scaled such that cell integral is 1)
        end
    end
end



function get_coefficients(::Type{ON_CELLS}, FE::FESpace{<:H1P3}, EG::Type{<:Triangle2D})
    xCellFaceSigns::Union{VariableTargetAdjacency{Int32},Array{Int32,2}} = FE.xgrid[CellFaceSigns]
    ncomponents = get_ncomponents(eltype(FE))
    function closure(coefficients::Array{<:Real,2}, cell::Int)
        fill!(coefficients,1.0)
        # multiplication with orientation factor
        for k = 1 : ncomponents
            coefficients[k,10*k-6] = xCellFaceSigns[1,cell];
            coefficients[k,10*k-5] = xCellFaceSigns[1,cell];
            coefficients[k,10*k-4] = xCellFaceSigns[2,cell];
            coefficients[k,10*k-3] = xCellFaceSigns[2,cell]; 
            coefficients[k,10*k-2] = xCellFaceSigns[3,cell]; 
            coefficients[k,10*k-1] = xCellFaceSigns[3,cell];
        end
        return nothing
    end
end 


# we need to change the ordering of the face dofs on faces that have a negative orientation sign
function get_basissubset(::Type{ON_CELLS}, FE::FESpace{<:H1P3}, EG::Type{<:Triangle2D})
    xCellFaceSigns = FE.xgrid[CellFaceSigns]
    nfaces::Int = nfaces_for_geometry(EG)
    ncomponents = get_ncomponents(eltype(FE))
    function closure(subset_ids::Array{Int,1}, cell)
        for j = 1 : nfaces
            if xCellFaceSigns[j,cell] == 1
                for c = 1 : ncomponents
                    subset_ids[(c-1)*10 + 3+2*j-1] = (c-1)*10 + 3+2*j
                    subset_ids[(c-1)*10 + 3+2*j] = (c-1)*10 + 3+2*j-1
                end
            else
                for c = 1 : ncomponents
                    subset_ids[(c-1)*10 + 3+2*j-1] = (c-1)*10 + 3+2*j-1
                    subset_ids[(c-1)*10 + 3+2*j] = (c-1)*10 + 3+2*j
                end
            end
        end
        println("subset_ids = $subset_ids")
        return nothing
    end
end  