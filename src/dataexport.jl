
# conversion from AbstractElementGeometry to WriteVTK.VTKCellTypes
VTKCellType(::Type{<:AbstractElementGeometry1D}) = VTKCellTypes.VTK_LINE
VTKCellType(::Type{<:Triangle2D}) = VTKCellTypes.VTK_TRIANGLE
VTKCellType(::Type{<:Quadrilateral2D}) = VTKCellTypes.VTK_QUAD
VTKCellType(::Type{<:Tetrahedron3D}) = VTKCellTypes.VTK_TETRA
VTKCellType(::Type{<:Hexahedron3D}) = VTKCellTypes.VTK_HEXAHEDRON

"""
$(TYPEDSIGNATURES)

Writes the specified FEVector into a vtk datafile with the given filename. Each FEVectorBlock in the Data array
is saved as separate VTKPointData. Vector-valued quantities also generate a data field
that represents the absolute value of the vector field at each grid point (if vectorabs is true).
"""
function writeVTK!(filename::String, Data::Array{<:FEVectorBlock,1}; operators = [], names = [], vectorabs::Bool = true, add_regions = false, caplength::Int = 40)
    # open grid
    xgrid = Data[1].FES.xgrid
    xCoordinates = xgrid[Coordinates]
    xdim = size(xCoordinates,1)
    nnodes = size(xCoordinates,2)
    xCellNodes = xgrid[CellNodes]
    xCellGeometries = xgrid[CellGeometries]
    xCellRegions = xgrid[CellRegions]
    ncells = num_sources(xCellNodes)

    ## add grid to file
    vtk_cells = Array{MeshCell,1}(undef,ncells)
    for item = 1 : ncells
        vtk_cells[item] = MeshCell(VTKCellType(xCellGeometries[item]), xCellNodes[:,item])
    end
    vtkfile = vtk_grid(filename, xCoordinates, vtk_cells)

    if add_regions
        vtkfile["grid_regions", VTKCellData()] = xCellRegions
    end

    ## add data
    nblocks::Int = length(Data)
    ncomponents::Int = 0
    maxcomponents::Int = 0
    nfields::Int = 0
    block::Int = 0
    for d = 1 : nblocks
        while length(operators) < d
            push!(operators, Identity)
        end
        ncomponents = Length4Operator(operators[d], xdim, get_ncomponents(eltype(Data[d].FES))) 
        if ncomponents > maxcomponents
            maxcomponents = ncomponents
        end
    end
    nodedata = zeros(Float64, maxcomponents, nnodes)
    
    for d = 1 : length(Data)
        # get node values
        ncomponents = Length4Operator(operators[d], xdim, get_ncomponents(eltype(Data[d].FES))) 
        nodevalues!(nodedata, Data[d], Data[d].FES, operators[d])
        if length(names) >= d
            fieldname = names[d]
        else
            fieldname = "$(operators[d])" * "(" * Data[d].name * ")"
            fieldname = fieldname[1:min(caplength,length(fieldname))]
            fieldname = replace(String(fieldname), " " => "_")
            fieldname = "$(d)_$fieldname"
        end    
        for c = 1 : ncomponents
            vtkfile["$fieldname.$c", VTKPointData()] = view(nodedata,c,:)
        end
        # add data for absolute value of vector quantity
        if vectorabs && ncomponents > 1
            vtkfile["$fieldname.a", VTKPointData()] = sqrt.(sum(view(nodedata,1:ncomponents,:).^2, dims = 1))
        end
    end

    ## save file
    outfiles = vtk_save(vtkfile)
    return nothing
end