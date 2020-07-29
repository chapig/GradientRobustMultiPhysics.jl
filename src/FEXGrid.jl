# Here goes all the stuff that connects this code to ExtendableGrids like
# - definition of additional adjacency types and their instantiation
# - connections between CellGeometries and FaceGeometries of their faces
# - formulas to compute Volumes and Normal Vectors etc.
# (some of this might become native in the ExtendableGrids module itself at some point)


# additional ElementGeometryTypes with parent information
#abstract type Vertex0DWithParent{Parent <: AbstractElementGeometry} <: Vertex0D end
#abstract type Vertex0DWithParents{Parent1 <: AbstractElementGeometry, Parent2 <: AbstractElementGeometry} <: Vertex0D end
#export Vertex0DWithParent, Vertex0DWithParents

#function AddParent(FEG::Type{<:Vertex0D}, CEG::Type{<:AbstractElementGeometry})
#    return Vertex0DWithParent{CEG}
#end

#abstract type Edge1DWithParent{Parent <: AbstractElementGeometry} <: Edge1D end
#abstract type Edge1DWithParents{Parent1 <: AbstractElementGeometry, Parent2 <: AbstractElementGeometry} <: Edge1D end
#export Edge1DWithParent, Edge1DWithParents

#function AddParent(FEG::Type{<:Edge1D}, CEG::Type{<:AbstractElementGeometry})
#    return Edge1DWithParent{CEG}
#end


# additional ExtendableGrids adjacency types 
abstract type EdgeNodes <: AbstractGridAdjacency end
abstract type FaceNodes <: AbstractGridAdjacency end
abstract type CellEdges <: AbstractGridAdjacency end
abstract type CellFaces <: AbstractGridAdjacency end
abstract type CellFaceSigns <: AbstractGridAdjacency end
abstract type CellVolumes <: AbstractGridFloatArray1D end
abstract type EdgeVolumes <: AbstractGridFloatArray1D end
abstract type FaceVolumes <: AbstractGridFloatArray1D end
abstract type EdgeCells <: AbstractGridAdjacency end
abstract type FaceCells <: AbstractGridAdjacency end
abstract type EdgeTangents <: AbstractGridFloatArray2D end
abstract type FaceNormals <: AbstractGridFloatArray2D end
abstract type EdgeGeometries <: AbstractElementGeometries end
abstract type FaceGeometries <: AbstractElementGeometries end
abstract type FaceRegions <: AbstractElementRegions end
abstract type BFaces <: AbstractGridIntegerArray1D end
abstract type BFaceCellPos <: AbstractGridIntegerArray1D end # position of bface in adjacent cell
abstract type BFaceVolumes <: AbstractGridFloatArray1D end


# unique functions that only selects uniques in specified regions
function uniqueEG(xItemGeometries, xItemRegions, xItemDofs, regions)
    nitems = 0
    try
        nitems = num_sources(xItemGeometries)
    catch
        nitems = length(xItemGeometries)
    end      
    EG::Array{DataType,1} = []
    ndofs4EG = Array{Array{Int,1},1}(undef,length(xItemDofs))
    for e = 1 : length(xItemDofs)
        ndofs4EG[e] = []
    end
    iEG = 0
    cellEG = Triangle2D
    for item = 1 : nitems
        for j = 1 : length(regions)
            if xItemRegions[item] == regions[j]
                cellEG = xItemGeometries[item]
                iEG = 0
                for k = 1 : length(EG)
                    if cellEG == EG[k]
                        iEG = k
                        break;
                    end
                end
                if iEG == 0
                    append!(EG, [xItemGeometries[item]])
                    for e = 1 : length(xItemDofs)
                        append!(ndofs4EG[e], num_targets(xItemDofs[e],item))
                    end
                end  
                break; # rest of for loop can be skipped
            end    
        end
    end    
    return EG, ndofs4EG
end

# function that specifies the number of nodes for an AbstractElementGeometry
nnodes_for_geometry(::Type{<:AbstractElementGeometry0D}) = 1
nnodes_for_geometry(::Type{<:AbstractElementGeometry1D}) = 2
nnodes_for_geometry(::Type{<:Triangle2D}) = 3
nnodes_for_geometry(::Type{<:Quadrilateral2D}) = 4
nnodes_for_geometry(::Type{<:Tetrahedron3D}) = 4
nnodes_for_geometry(::Type{<:Hexahedron3D}) = 8

# functions that specify the number of faces of a celltype
# (and also the number of edges of a facetype)
nfaces_for_geometry(::Type{<:AbstractElementGeometry1D}) = 2
nfaces_for_geometry(::Type{<:Triangle2D}) = 3
nfaces_for_geometry(::Type{<:Quadrilateral2D}) = 4
nfaces_for_geometry(::Type{<:Tetrahedron3D}) = 4
nfaces_for_geometry(::Type{<:Hexahedron3D}) = 6

# functions that specify the number of edges of a celltype
# (and also the number of edges of a facetype)
nedges_for_geometry(::Type{<:AbstractElementGeometry0D}) = 0
nedges_for_geometry(::Type{<:AbstractElementGeometry1D}) = 0
nedges_for_geometry(EG::Type{<:AbstractElementGeometry2D}) = nnodes_for_geometry(EG)
nedges_for_geometry(::Type{<:Tetrahedron3D}) = 6
nedges_for_geometry(::Type{<:Hexahedron3D}) = 12

# functions that specify the local enumeration of faces needed in 2D/3D
face_enum_rule(::Type{<:Edge1D}) = [1; 2]
face_enum_rule(::Type{<:Triangle2D}) = [1 2; 2 3; 3 1]
face_enum_rule(::Type{<:Quadrilateral2D}) = [1 2; 2 3; 3 4; 4 1]
face_enum_rule(::Type{<:Tetrahedron3D}) = [1 2 3; 1 2 4; 2 3 4; 3 1 4]
face_enum_rule(::Type{<:Hexahedron3D}) = [1 2 5 3; 1 2 6 4; 2 5 8 6;5 3 7 8;3 1 4 7;4 6 8 7]

# functions that specify the facetype of the k-th cellface
facetype_of_cellface(P1::Type{<:AbstractElementGeometry1D},P2::Type{<:AbstractElementGeometry1D}, k) = Vertex0D
facetype_of_cellface(P1::Type{<:AbstractElementGeometry2D},P2::Type{<:AbstractElementGeometry2D}, k) = Edge1D
facetype_of_cellface(P1::Type{<:Tetrahedron3D},P2::Type{<:Tetrahedron3D}, k) = Parallelogram2D
facetype_of_cellface(P1::Type{<:Hexahedron3D},P2::Type{<:Hexahedron3D}, k) = Parallelogram2D
facetype_of_cellface(::Type{<:Edge1D}, k) = Vertex0D
facetype_of_cellface(::Type{<:Triangle2D}, k) = Edge1D #WithParent{Triangle2D}
facetype_of_cellface(::Type{<:Quadrilateral2D}, k) = Edge1D #WithParent{Quadrilateral2D}
facetype_of_cellface(::Type{<:Tetrahedron3D}, k) = Triangle2D
facetype_of_cellface(::Type{<:Hexahedron3D}, k) = Quadrilateral2D
facetype_of_cellface(::Type{<:Parallelepiped3D}, k) = Parallelogram2D


# function that specify the local enumeration of edges needed in 3D
# idea for future: edge_enum should be EdgeNodes of face_enum of all faces
edge_enum_rule(::Type{<:Tetrahedron3D}) = [1 2; 1 3; 1 4; 2 3; 2 4; 3 4]
edge_enum_rule(::Type{<:Hexahedron3D}) = [1 2; 1 3; 1 4; 2 5; 2 6; 3 5; 3 7; 4 6; 4 7; 5 8; 6 8; 7 8]
edgetype_of_celledge(::Type{<:AbstractElementGeometry3D}, k) = Edge1D

# function that yields the local edge numbers of a local face of a 3D geometry
celledges_for_cellface(::Type{<:Tetrahedron3D}) = [1 4 2; 1 5 3; 4 6 5; 2 3 6]
celledges_for_cellface(::Type{<:Hexahedron3D}) = [1 4 6 2; 1 5 8 3; 4 10 11 5; 6 7 12 10; 2 3 9 7; 8 11 12 9]




# show function for ExtendableGrids and defined Components in its Dict
function show(xgrid::ExtendableGrid)

    dim = size(xgrid[Coordinates],1)
    nnodes = num_sources(xgrid[Coordinates])
    ncells = num_sources(xgrid[CellNodes])
    
	println("ExtendableGrids");
    println("======");
	println("dim: $(dim)")
	println("nnodes: $(nnodes)")
    println("ncells: $(ncells)")
    if haskey(ExtendableGrids.components,FaceNodes)
        nfaces = num_sources(xgrid[FaceNodes])
        println("nfaces: $(nfaces)")
    else
        println("nfaces: (FaceNodes not instantiated)")
    end
    println("")
    println("Components");
    println("===========");
    for tuple in ExtendableGrids.components
        println("> $(tuple[1])")
    end
end


# FaceNodes = nodes for each face (implicitly defines the enumerations of faces)
function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{FaceNodes})

    xCellNodes = xgrid[CellNodes]
    ncells = num_sources(xCellNodes)
    nnodes = num_sources(xgrid[Coordinates])
    xCellGeometries = xgrid[CellGeometries]
    dim = dim_element(xCellGeometries[1])

    #transpose CellNodes to get NodeCells
    xNodeCells = atranspose(xCellNodes)
    max_ncell4node = max_num_targets_per_source(xNodeCells)
    xFaceNodes = VariableTargetAdjacency(Int32)
    xCellFaces = VariableTargetAdjacency(Int32)
    xFaceCells = zeros(Int32,0) # cells are appended and at the end rewritten into 2,nfaces array
    xCellFaceSigns = VariableTargetAdjacency(Int32)
    xFaceGeometries::Array{DataType,1} = []
    xBFaces::Array{Int32,1} = []

    cellEG = Triangle2D
    # pre-allocate xCellFaces
    for cell = 1 : ncells
        cellEG = xCellGeometries[cell]
        append!(xCellFaces,zeros(Int32,nfaces_for_geometry(cellEG)))
        append!(xCellFaceSigns,zeros(Int32,nfaces_for_geometry(cellEG)))
    end   

    # loop over cells
    node::Int32 = 0
    face::Int32 = 0
    cell::Int32 = 0
    cell2::Int32 = 0
    cell2EG = Triangle2D
    nneighbours::Int32 = 0
    faces_per_cell::Int32 = 0
    faces_per_cell2::Int32 = 0
    nodes_per_cellface::Int32 = 0
    nodes_per_cellface2::Int32 = 0
    common_nodes::Int32 = 0
    current_item = zeros(Int32,max_num_targets_per_source(xCellNodes)) # should be large enough to store largest nnodes per cellface
    flag4item = zeros(Bool,nnodes)
    
    for cell = 1 : ncells
        cellEG = xCellGeometries[cell]
        faces_per_cell = nfaces_for_geometry(cellEG)
        face_rule = face_enum_rule(cellEG)

        # loop over cell faces
        for k = 1 : faces_per_cell

            # check if face is already known to cell
            if xCellFaces[k,cell] > 0
                continue;
            end    

            nodes_per_cellface = nnodes_for_geometry(facetype_of_cellface(cellEG, k))

            # flag face nodes and commons4cells
            for j = nodes_per_cellface:-1:1
                node = xCellNodes[face_rule[k,j],cell]
                current_item[j] = node
                flag4item[node] = true; 
            end

            # get neighbours for first node
            nneighbours = num_targets(xNodeCells,node)

            # loop over neighbours
            no_neighbours_found = true
            common_nodes = 0
            for n = 1 : nneighbours
                cell2 = xNodeCells[n,node]

                # skip if cell2 is the same as cell
                if (cell == cell2) 
                    continue; 
                end

                # loop over faces of cell2
                cell2EG = xCellGeometries[cell2]
                faces_per_cell2 = nfaces_for_geometry(cell2EG)
                face_rule2 = face_enum_rule(cell2EG)
                for f2 = 1 : faces_per_cell2
                    # check if face is already known to cell2
                    if xCellFaces[f2,cell2] > 0
                        continue;
                    end    

                    #otherwise compare nodes of face and face2
                    nodes_per_cellface2 = nnodes_for_geometry(facetype_of_cellface(cell2EG, f2))
                    common_nodes = 0
                    if nodes_per_cellface == nodes_per_cellface2
                        for j = 1 : nodes_per_cellface2
                            if flag4item[xCellNodes[face_rule2[f2,j],cell2]]
                                common_nodes += 1
                            else
                                continue;    
                            end    
                        end
                    end

                    # if all nodes are the same, register face
                    if (common_nodes == nodes_per_cellface2)
                        no_neighbours_found = false
                        face += 1
                        # set index for adjacencies missing
                        #xCellFaces[k,cell] = face
                        #xCellFaces[f2,cell2] = face
                        push!(xFaceCells,cell)
                        push!(xFaceCells,cell2)
                        xCellFaces.colentries[xCellFaces.colstart[cell]+k-1] = face
                        xCellFaces.colentries[xCellFaces.colstart[cell2]+f2-1] = face
                        xCellFaceSigns.colentries[xCellFaceSigns.colstart[cell]+k-1] = 1
                        xCellFaceSigns.colentries[xCellFaceSigns.colstart[cell2]+f2-1] = -1
                        append!(xFaceNodes,view(current_item,1:nodes_per_cellface))
                        push!(xFaceGeometries,facetype_of_cellface(cellEG,cell2EG,k))
                        break;
                    end

                end
            end

            # if no common neighbour cell is found, register face (boundary faces)
            if no_neighbours_found == true
                face += 1
                # set index for adjacencies missing
                #xCellFaces[k,cell] = face
                push!(xFaceCells,cell)
                push!(xFaceCells,0)
                xCellFaces.colentries[xCellFaces.colstart[cell]+k-1] = face
                xCellFaceSigns.colentries[xCellFaceSigns.colstart[cell]+k-1] = 1
                append!(xFaceNodes,view(current_item,1:nodes_per_cellface))
                push!(xFaceGeometries,facetype_of_cellface(cellEG,k))
            end

            #reset flag4item
            for j = 1:nodes_per_cellface
                flag4item[current_item[j]] = false 
            end
        end    
    end
    xgrid[FaceGeometries] = xFaceGeometries
    xgrid[CellFaces] = xCellFaces
    xgrid[CellFaceSigns] = xCellFaceSigns
    xgrid[FaceCells] = reshape(xFaceCells,2,Int64(face))
    xFaceNodes
end



# FaceNodes = nodes for each face (implicitly defines the enumerations of faces)
function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{EdgeNodes})

    dim = size(xgrid[Coordinates],1) 
    xCellNodes = xgrid[CellNodes]
    ncells = num_sources(xCellNodes)
    nnodes = num_sources(xgrid[Coordinates])
    xCellGeometries = xgrid[CellGeometries]
    dim = dim_element(xCellGeometries[1])
    if dim < 2
        # do nothing in 2D: alternative one could think of returning FaceNodes or a field 1:nnodes instead (as the edges in 2D would be vertices)
        return
    end

    #transpose CellNodes to get NodeCells
    xNodeCells = atranspose(xCellNodes)
    max_ncell4node = max_num_targets_per_source(xNodeCells)

    xEdgeNodes = VariableTargetAdjacency(Int32)
    xEdgeCells = VariableTargetAdjacency(Int32)
    xCellEdges = VariableTargetAdjacency(Int32)

    xEdgeGeometries::Array{DataType,1} = []

    current_item = zeros(Int32,2) # should be large enough to store largest nnodes_per_celledge
    flag4item = zeros(Bool,nnodes)
    cellEG = Triangle2D
    node = 0
    node_cells = zeros(Int32,max_ncell4node) # should be large enough to store largest nnodes_per_celledge
    item = 0
    nneighbours = 0
    edges_per_cell = 0
    edges_per_cell2 = 0
    nodes_per_celledge = 0
    nodes_per_celledge2 = 0
    common_nodes = 0
    # pre-allocate xCellEdges
    for cell = 1 : ncells
        cellEG = xCellGeometries[cell]
        append!(xCellEdges,zeros(Int32,nedges_for_geometry(cellEG)))
        #append!(xCellEdgeSigns,zeros(Int32,nedges_for_geometry(cellEG)))
    end   

    # loop over cells
    cells_with_common_edge = zeros(Int32,max_ncell4node)
    pos_in_cells_with_common_edge = zeros(Int32,max_ncell4node)
    ncells_with_common_edge = 0
    edge = 0
    for cell = 1 : ncells
        cellEG = xCellGeometries[cell]
        edges_per_cell = nedges_for_geometry(cellEG)
        edge_rule = edge_enum_rule(cellEG)

        # loop over cell edges
        for k = 1 : edges_per_cell

            # check if edge is already known to cell
            if xCellEdges[k,cell] > 0
                continue;
            end    
            nodes_per_celledge = nnodes_for_geometry(edgetype_of_celledge(cellEG, k))
            ncells_with_common_edge = 1
            cells_with_common_edge[1] = cell
            pos_in_cells_with_common_edge[1] = k

            # flag edge nodes and commons4cells
            for j = 1 : nodes_per_celledge
                node = xCellNodes[edge_rule[k,j],cell]
                current_item[j] = node
                flag4item[node] = true; 
            end

            # get first node and its neighbours
            node = xCellNodes[edge_rule[k,1],cell]
            nneighbours = num_targets(xNodeCells,node)
            node_cells[1:nneighbours] = xNodeCells[:,node]

            # loop over neighbours
            for n = 1 : nneighbours
                cell2 = node_cells[n]

                # skip if cell2 is the same as cell
                if (cell == cell2) 
                    continue; 
                end

                # loop over edges of cell2
                cell2EG = xCellGeometries[cell2]
                edges_per_cell2 = nedges_for_geometry(cell2EG)
                edge_rule2 = edge_enum_rule(cell2EG)
                for f2 = 1 : edges_per_cell2
                    # compare nodes of face and face2
                    nodes_per_celledge2 = nnodes_for_geometry(edgetype_of_celledge(cell2EG, f2))
                    common_nodes = 0
                    if nodes_per_celledge == nodes_per_celledge2
                        for j = 1 : nodes_per_celledge2
                            if flag4item[xCellNodes[edge_rule2[f2,j],cell2]]
                                common_nodes += 1
                            else
                                continue;    
                            end    
                        end
                    end

                    # if all nodes are the same, register edge
                    if (common_nodes == nodes_per_celledge2)
                        ncells_with_common_edge += 1
                        cells_with_common_edge[ncells_with_common_edge] = cell2
                        pos_in_cells_with_common_edge[ncells_with_common_edge] = f2
                    end

                end
            end

            # register edge
            edge += 1
            for c = 1 : ncells_with_common_edge
                xCellEdges.colentries[xCellEdges.colstart[cells_with_common_edge[c]]+pos_in_cells_with_common_edge[c]-1] = edge
            end
            append!(xEdgeCells,cells_with_common_edge)
            append!(xEdgeNodes,current_item[1:nodes_per_celledge])
            push!(xEdgeGeometries,edgetype_of_celledge(cellEG,k))

            #reset flag4item
            for j = 1 : nnodes
                flag4item[j] = 0
            end    
        end    
    end
    xgrid[EdgeGeometries] = xEdgeGeometries
    xgrid[CellEdges] = xCellEdges
    xgrid[EdgeCells] = xEdgeCells
    xEdgeNodes
end



# CellFaces = faces for each cell
function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{CellFaces})
    ExtendableGrids.instantiate(xgrid, FaceNodes)
    xgrid[CellFaces]
end

# CellFaceSigns = orientation signs for each face on each cell
function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{CellFaceSigns})
    ExtendableGrids.instantiate(xgrid, FaceNodes)
    xgrid[CellFaceSigns]
end



# some methods to compute volume of different ElemTypes (beware: on submanifolds formulas get different)

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Vertex0D}, ::Type{<:ExtendableGrids.AbstractCoordinateSystem})
    return 0.0
end

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Edge1D}, ::Type{Cartesian1D})
    return abs(Coords[1, Nodes[2,item]] - Coords[1, Nodes[1,item]])
end

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Edge1D}, ::Type{Cartesian2D})
    return sqrt((Coords[1, Nodes[2,item]] - Coords[1, Nodes[1,item]]).^2 + (Coords[2, Nodes[2,item]] - Coords[2, Nodes[1,item]]).^2)
end

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Triangle2D}, ::Type{Cartesian2D})
    return 1 // 2 * ( Coords[1, Nodes[1, item]] * (Coords[2, Nodes[2,item]] -  Coords[2, Nodes[3, item]])
                  +   Coords[1, Nodes[2, item]] * (Coords[2, Nodes[3,item]] -  Coords[2, Nodes[1, item]])
                  +   Coords[1, Nodes[3, item]] * (Coords[2, Nodes[1,item]] -  Coords[2, Nodes[2, item]]) )
end

#function Volume4ElemType(Coords, Nodes, item, ::Type{Parallelogram2D}, ::Type{Cartesian2D})
#    return ( Coords[1, Nodes[1, item]] * (Coords[2, Nodes[2,item]] -  Coords[2, Nodes[3, item]])
#           + Coords[1, Nodes[2, item]] * (Coords[2, Nodes[3,item]] -  Coords[2, Nodes[1, item]])
#           + Coords[1, Nodes[3, item]] * (Coords[2, Nodes[1,item]] -  Coords[2, Nodes[2, item]]) )
#end

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Quadrilateral2D}, ::Type{Cartesian2D})
    return 1//2 * (   (Coords[1, Nodes[1, item]] - Coords[1, Nodes[3, item]]) * (Coords[2, Nodes[2, item]] - Coords[2, Nodes[4, item]])
                    + (Coords[1, Nodes[4, item]] - Coords[1, Nodes[2, item]]) * (Coords[2, Nodes[1, item]] - Coords[2, Nodes[3, item]]) );
end


function Volume4ElemType(Coords, Nodes, item, ::Type{<:Triangle2D}, ::Type{Cartesian3D})
    # norm(cross(p(1)-p(2), p(1)-p(3)), 2)
    d12 = Coords[:, Nodes[1, item]] - Coords[:, Nodes[2, item]]
    d14 = Coords[:, Nodes[1, item]] - Coords[:, Nodes[3, item]]
    return sqrt((d12[2]*d14[3]-d12[3]*d14[2])^2 + (d12[3]*d14[1]-d12[1]*d14[3])^2 + (d12[1]*d14[2]-d12[2]*d14[1])^2) / 2;
end

function Volume4ElemType(Coords, Nodes, item, ::Type{<:Parallelogram2D}, ::Type{Cartesian3D})
    # norm(cross(p(1)-p(2), p(1)-p(3)), 2)
    d12 = Coords[:, Nodes[1, item]] - Coords[:, Nodes[2, item]]
    d14 = Coords[:, Nodes[1, item]] - Coords[:, Nodes[4, item]]
    return sqrt((d12[2]*d14[3]-d12[3]*d14[2])^2 + (d12[3]*d14[1]-d12[1]*d14[3])^2 + (d12[1]*d14[2]-d12[2]*d14[1])^2);
end


function Volume4ElemType(Coords, Nodes, item, ::Type{<:Parallelepiped3D}, ::Type{Cartesian3D})
    return    ((Coords[1, Nodes[4, item]] - Coords[1, Nodes[1, item]]) * ( (Coords[2, Nodes[2, item]] - Coords[2, Nodes[1, item]]) * (Coords[3, Nodes[3, item]] - Coords[3, Nodes[1, item]]) - (Coords[2, Nodes[3, item]] - Coords[2, Nodes[1, item]]) * (Coords[3, Nodes[2, item]] - Coords[3, Nodes[1, item]])) 
    + (Coords[2, Nodes[4, item]] - Coords[2, Nodes[1, item]]) * ( (Coords[3, Nodes[2, item]] - Coords[3, Nodes[1, item]]) * (Coords[1, Nodes[3, item]] - Coords[1, Nodes[1, item]]) - (Coords[1, Nodes[2, item]] - Coords[1, Nodes[1, item]]) * (Coords[3, Nodes[3, item]] - Coords[3, Nodes[1, item]])) 
    + (Coords[3, Nodes[4, item]] - Coords[3, Nodes[1, item]]) * ( (Coords[1, Nodes[2, item]] - Coords[1, Nodes[1, item]]) * (Coords[2, Nodes[3, item]] - Coords[2, Nodes[1, item]]) - (Coords[2, Nodes[2, item]] - Coords[2, Nodes[1, item]]) * (Coords[1, Nodes[3, item]] - Coords[1, Nodes[1, item]])));
end


function Volume4ElemType(Coords, Nodes, item, ::Type{<:Tetrahedron3D}, ::Type{Cartesian3D})
    return    1 // 6 * ((Coords[1, Nodes[4, item]] - Coords[1, Nodes[1, item]]) * ( (Coords[2, Nodes[2, item]] - Coords[2, Nodes[1, item]]) * (Coords[3, Nodes[3, item]] - Coords[3, Nodes[1, item]]) - (Coords[2, Nodes[3, item]] - Coords[2, Nodes[1, item]]) * (Coords[3, Nodes[2, item]] - Coords[3, Nodes[1, item]])) 
    + (Coords[2, Nodes[4, item]] - Coords[2, Nodes[1, item]]) * ( (Coords[3, Nodes[2, item]] - Coords[3, Nodes[1, item]]) * (Coords[1, Nodes[3, item]] - Coords[1, Nodes[1, item]]) - (Coords[1, Nodes[2, item]] - Coords[1, Nodes[1, item]]) * (Coords[3, Nodes[3, item]] - Coords[3, Nodes[1, item]])) 
    + (Coords[3, Nodes[4, item]] - Coords[3, Nodes[1, item]]) * ( (Coords[1, Nodes[2, item]] - Coords[1, Nodes[1, item]]) * (Coords[2, Nodes[3, item]] - Coords[2, Nodes[1, item]]) - (Coords[2, Nodes[2, item]] - Coords[2, Nodes[1, item]]) * (Coords[1, Nodes[3, item]] - Coords[1, Nodes[1, item]])));
end
  


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{CellVolumes})

    # get links to other stuff
    xCoordinates = xgrid[Coordinates]
    xCellNodes = xgrid[CellNodes]
    ncells = num_sources(xCellNodes)
    xCellGeometries = xgrid[CellGeometries]
    xCoordinateSystem = xgrid[CoordinateSystem]

    # init CellVolumes
    xCellVolumes = zeros(Real,ncells)

    for cell = 1 : ncells
        xCellVolumes[cell] = Volume4ElemType(xCoordinates,xCellNodes,cell,xCellGeometries[cell],xCoordinateSystem)
    end

    xCellVolumes
end


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{FaceVolumes})

    # get links to other stuff
    xCoordinates = xgrid[Coordinates]
    xFaceNodes = xgrid[FaceNodes]
    nfaces = num_sources(xFaceNodes)
    xFaceGeometries = xgrid[FaceGeometries]
    xCoordinateSystem = xgrid[CoordinateSystem]

    # init FaceVolumes
    xFaceVolumes = zeros(Real,nfaces)

    for face = 1 : nfaces
        xFaceVolumes[face] = Volume4ElemType(xCoordinates,xFaceNodes,face,xFaceGeometries[face],xCoordinateSystem)
    end

    xFaceVolumes
end


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{BFaceVolumes})

    # get links to other stuff
    xCoordinates = xgrid[Coordinates]
    xBFaceNodes = xgrid[BFaceNodes]
    nbfaces = num_sources(xBFaceNodes)
    xBFaceGeometries = xgrid[BFaceGeometries]
    xCoordinateSystem = xgrid[CoordinateSystem]

    # init FaceVolumes
    xBFaceVolumes = zeros(Real,nbfaces)

    for bface = 1 : nbfaces
        xBFaceVolumes[bface] = Volume4ElemType(xCoordinates,xBFaceNodes,bface,xBFaceGeometries[bface],xCoordinateSystem)
    end

    xBFaceVolumes
end


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{BFaces})
    # get links to other stuff
    xCoordinates = xgrid[Coordinates]
    xFaceNodes = xgrid[FaceNodes]
    xBFaceNodes = xgrid[BFaceNodes]
    nnodes = num_sources(xCoordinates)
    nbfaces = num_sources(xBFaceNodes)
    nfaces = num_sources(xFaceNodes)
    flag4item = zeros(Bool,nnodes)

    # init BFaces
    xBFaces = zeros(Int32,nbfaces)
    #xBFaceGeometries = xgrid[BFaceGeometries]
    #if typeof(xBFaceGeometries) == VectorOfConstants{DataType}
    #    EG = xBFaceGeometries[1]
    #    xBFaceGeometries = Array{DataType,1}(undef,nbfaces)
    #    for j = 1 : nbfaces
    #        xBFaceGeometries[j] = EG
    #    end
    #end

    nodes_per_bface::Int32 = 0
    nodes_per_face::Int32 = 0
    swap::Int32 = 0
    common_nodes = 0
    for bface = 1 : nbfaces
        nodes_per_bface = num_targets(xBFaceNodes,bface)
        for j = 1 : nodes_per_bface
            flag4item[xBFaceNodes[j,bface]] = true
        end    
        
        # find matching face
        for face = 1 : nfaces
            nodes_per_face = num_targets(xFaceNodes,face)
            common_nodes = 0
            for k = 1 : nodes_per_face
                if flag4item[xFaceNodes[k,face]] == true
                    common_nodes += 1
                else
                    continue;  
                end
            end          
            if common_nodes == nodes_per_face
                xBFaces[bface] = face
                break
            end
        end

        if xBFaces[bface] == 0
            println("WARNING(BFaces): found no matching face for bface $bface with nodes $(xBFaceNodes[:,bface])")
        end

        for j = 1 : nodes_per_bface
            flag4item[xBFaceNodes[j,bface]] = false
        end    
    end

   # xgrid[BFaceGeometries] = xBFaceGeometries
    xBFaces
end


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{FaceCells})
    ExtendableGrids.instantiate(xgrid, FaceNodes)
    xgrid[FaceCells]
end

function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{CellEdges})
    ExtendableGrids.instantiate(xgrid, EdgeNodes)
    xgrid[CellEdges]
end

# This assigns Regions to faces by looking at neighbouring cells
# don't know yet if this is a good idea

function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{FaceRegions})
    return VectorOfConstants(Int32(0),num_sources(xgrid[FaceNodes]))
end


function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{BFaceCellPos})

    # get links to other stuff
    xCoordinates = xgrid[Coordinates]
    xCellFaces = xgrid[CellFaces]
    xFaceCells = xgrid[FaceCells]
    xBFaces = xgrid[BFaces]
    nbfaces = length(xBFaces)

    # init BFaces
    xBFaceCellPos = zeros(Int32,nbfaces)

    cface = 0
    cell = 0
    nfaces4cell = 0
    for bface = 1 : nbfaces
        cface = xBFaces[bface]
        cell = xFaceCells[1,cface]
        nfaces4cell = num_targets(xCellFaces,cell)
        for face = 1 : nfaces4cell
            if cface == xCellFaces[face,cell]
                xBFaceCellPos[bface] = face
                break
            end
        end
    end

    xBFaceCellPos
end



function Normal4ElemType!(normal, Coords, Nodes, item, ::Type{<:Vertex0D}, ::Type{Cartesian2D})
    normal[1] = 0.0
    normal[2] = 0.0
end

function Normal4ElemType!(normal, Coords, Nodes, item, ::Type{<:Vertex0D}, ::Type{Cartesian1D})
    normal[1] = 1.0
end

function Normal4ElemType!(normal, Coords, Nodes, item, ::Type{<:Edge1D}, ::Type{Cartesian2D})
    # rotate tangent
    normal[1] = Coords[2, Nodes[2,item]] - Coords[2,Nodes[1,item]]
    normal[2] = Coords[1,Nodes[1,item]] - Coords[1, Nodes[2,item]]
    # divide by length
    normal ./= sqrt(normal[1]^2+normal[2]^2)
end

function ExtendableGrids.instantiate(xgrid::ExtendableGrid, ::Type{FaceNormals})

    # get links to other stuff
    dim = size(xgrid[Coordinates],1) 
    xCoordinates = xgrid[Coordinates]
    xFaceNodes = xgrid[FaceNodes]
    nfaces = num_sources(xFaceNodes)
    xFaceGeometries = xgrid[FaceGeometries]
    xCoordinateSystem = xgrid[CoordinateSystem]

    # init FaceNormals
    xFaceNormals = zeros(Real,dim,nfaces)
    normal = zeros(Real,dim)
    for face = 1 : nfaces
        Normal4ElemType!(normal,xCoordinates,xFaceNodes,face,xFaceGeometries[face],xCoordinateSystem)
        for k = 1 : dim
            xFaceNormals[k, face] = normal[k]
        end    
    end

    xFaceNormals
end
