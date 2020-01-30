module FESolveStokes

export solveStokesProblem!

using ExtendableSparse
using SparseArrays
using LinearAlgebra
using BenchmarkTools
using FiniteElements
using FESolveCommon
using DiffResults
using ForwardDiff
using Grid
using Quadrature

function assemble_divdiv_Matrix!(A::ExtendableSparseMatrix, FE_velocity::FiniteElements.AbstractH1FiniteElement)

    T = eltype(FE_velocity.grid.coords4nodes);
    ET = FE_velocity.grid.elemtypes[1]
    ndofs4cell_velocity::Int = FiniteElements.get_ndofs4elemtype(FE_velocity, ET);
    ncomponents::Int = FiniteElements.get_ncomponents(FE_velocity);
    ndofs_velocity = FiniteElements.get_ndofs(FE_velocity);
    ncells::Int = size(FE_velocity.grid.nodes4cells,1);
    xdim::Int = size(FE_velocity.grid.coords4nodes,2);
    
    @assert ncomponents == xdim
    
    quadorder = 2*(FiniteElements.get_polynomial_order(FE_velocity)-1);
    qf = QuadratureFormula{T,typeof(ET)}(quadorder);

    # pre-allocate gradients of basis function in reference coordinates
    celldim::Int = size(FE_velocity.grid.nodes4cells,2);
    gradients_xref_cache = zeros(Float64,length(qf.w),xdim*ndofs4cell_velocity,celldim)
    for i in eachindex(qf.w)
        # evaluate gradients of basis function
        gradients_xref_cache[i,:,:] = ForwardDiff.jacobian(FiniteElements.get_basis_on_elemtype(FE_velocity, ET),qf.xref[i]);
    end    
    
    # determine needed trafo
    loc2glob_trafo_tinv = Grid.local2global_tinv_jacobian(FE_velocity.grid,ET)
    trafo_jacobian = Matrix{T}(undef,xdim,xdim);
        
    # pre-allocate memory for temporary stuff
    gradients4cell = Array{Array{T,1}}(undef,xdim*ndofs4cell_velocity);
    for j = 1 : xdim*ndofs4cell_velocity
        gradients4cell[j] = zeros(T,xdim);
    end
    dofs_velocity = zeros(Int64,ndofs4cell_velocity)
    coefficients_velocity = zeros(Float64,ndofs4cell_velocity,xdim)
    div_i::T = 0.0;
    div_j::T = 0.0;
    offsets = [0,ndofs4cell_velocity];
    
    # audrature loop
    #@time begin
    for cell = 1 : ncells
      # evaluate tinverted (=transposed + inverted) jacobian of element trafo
      loc2glob_trafo_tinv(trafo_jacobian,cell)
      
      # get dofs
      FiniteElements.get_dofs_on_cell!(dofs_velocity,FE_velocity, cell, ET);
      
      # get coefficients
      FiniteElements.get_basis_coefficients_on_cell!(coefficients_velocity,FE_velocity,cell, ET);
      
      for i in eachindex(qf.w)
    
        # multiply tinverted jacobian of element trafo with gradient of basis function
        # which yields (by chain rule) the gradient in x coordinates
        for dof_i = 1 : ndofs4cell_velocity
            for c=1 : xdim, k = 1 : xdim
                gradients4cell[dof_i + offsets[c]][k] = 0.0;
                for j = 1 : xdim
                    gradients4cell[dof_i + offsets[c]][k] += trafo_jacobian[k,j]*gradients_xref_cache[i,dof_i + offsets[c],j] * coefficients_velocity[dof_i,c]
                end    
            end    
        end    
        
        # div x div velocity
        for dof_i = 1 : ndofs4cell_velocity
            div_i = 0.0;
            for c = 1 : xdim
                div_i -= gradients4cell[offsets[c]+dof_i][c];
            end    
            div_i *= qf.w[i] * FE_velocity.grid.volume4cells[cell];
            for dof_j = 1 : ndofs4cell_velocity
                div_j = 0.0;
                for c = 1 : xdim
                    div_j -= gradients4cell[offsets[c]+dof_j][c];
                end    
                A[dofs_velocity[dof_i],dofs_velocity[dof_j]] += div_j*div_i;
            end
        end    
      end  
    end
    #end  
end



function assemble_Stokes_Operator4FE!(A::ExtendableSparseMatrix, nu::Real, FE_velocity::FiniteElements.AbstractH1FiniteElement, FE_pressure::FiniteElements.AbstractH1FiniteElement, pressure_diagonal = 1e-6)

    T = eltype(FE_velocity.grid.coords4nodes);
    ET = FE_velocity.grid.elemtypes[1]
    ndofs4cell_velocity::Int = FiniteElements.get_ndofs4elemtype(FE_velocity, ET);
    ndofs4cell_pressure::Int = FiniteElements.get_ndofs4elemtype(FE_pressure, ET);
    ncomponents::Int = FiniteElements.get_ncomponents(FE_velocity);
    ndofs_velocity = FiniteElements.get_ndofs(FE_velocity);
    ndofs = ndofs_velocity + FiniteElements.get_ndofs(FE_pressure);
    ndofs4cell::Int = ndofs4cell_velocity+ndofs4cell_pressure;
    ncells::Int = size(FE_velocity.grid.nodes4cells,1);
    xdim::Int = size(FE_velocity.grid.coords4nodes,2);
    
    # check thate FE_velocity is vector-valued
    @assert ncomponents == xdim
    
    quadorder = maximum([FiniteElements.get_polynomial_order(FE_pressure) + FiniteElements.get_polynomial_order(FE_velocity)-1, 2*(FiniteElements.get_polynomial_order(FE_velocity)-1)]);
    qf = QuadratureFormula{T,typeof(ET)}(quadorder);

    # evaluate basis functions at quadrature points in reference coordinates
    celldim::Int = size(FE_velocity.grid.nodes4cells,2);
    gradients_xref_cache = zeros(Float64,length(qf.w),xdim*ndofs4cell_velocity,celldim)
    pressure_vals = Array{Array{T,1}}(undef,length(qf.w))
    for i in eachindex(qf.w)
        # evaluate gradients of basis function
        gradients_xref_cache[i,:,:] = ForwardDiff.jacobian(FiniteElements.get_basis_on_elemtype(FE_velocity, ET),qf.xref[i]);
        # evaluate pressure
        pressure_vals[i] = FiniteElements.get_basis_on_elemtype(FE_pressure, ET)(qf.xref[i]);
    end
    
    # get needed trafo
    loc2glob_trafo_tinv = Grid.local2global_tinv_jacobian(FE_velocity.grid,ET)
    trafo_jacobian = Matrix{T}(undef,xdim,xdim);
    
    
    # pre-allocate memory for temporary stuff
    gradients4cell = Array{Array{T,1}}(undef,xdim*ndofs4cell_velocity);
    for j = 1 : xdim*ndofs4cell_velocity
        gradients4cell[j] = zeros(T,xdim);
    end    
    dofs_velocity = zeros(Int64,ndofs4cell_velocity)
    dofs_pressure = zeros(Int64,ndofs4cell_pressure)
    coefficients_velocity = zeros(Float64,ndofs4cell_velocity,xdim)
    coefficients_pressure = zeros(Float64,ndofs4cell_pressure)
    temp::T = 0.0;
    offsets = [0,ndofs4cell_velocity];
    
    # quadrature loop
    #@time begin
    for cell = 1 : ncells
      # evaluate tinverted (=transposed + inverted) jacobian of element trafo
      loc2glob_trafo_tinv(trafo_jacobian,cell)
      
      # get dofs
      FiniteElements.get_dofs_on_cell!(dofs_velocity,FE_velocity, cell, ET);
      FiniteElements.get_dofs_on_cell!(dofs_pressure,FE_pressure, cell, ET);
      dofs_pressure .+= ndofs_velocity;
      
      # get coefficients
      FiniteElements.get_basis_coefficients_on_cell!(coefficients_velocity,FE_velocity,cell, ET);
      FiniteElements.get_basis_coefficients_on_cell!(coefficients_pressure,FE_pressure,cell, ET);
      
      for i in eachindex(qf.w)
      
        # multiply tinverted jacobian of element trafo with gradient of basis function
        # which yields (by chain rule) the gradient in x coordinates
        for dof_i = 1 : ndofs4cell_velocity
            for c=1 : xdim, k = 1 : xdim
                gradients4cell[dof_i + offsets[c]][k] = 0.0;
                for j = 1 : xdim
                    gradients4cell[dof_i + offsets[c]][k] += trafo_jacobian[k,j]*gradients_xref_cache[i,dof_i + offsets[c],j] * coefficients_velocity[dof_i,c]
                end    
            end    
        end    
         
        # fill sparse array
        for dof_i = 1 : ndofs4cell_velocity
            # stiffness matrix for velocity
            for dof_j = 1 : ndofs4cell_velocity
                temp = 0.0;
                for k = 1 : xdim
                    for c = 1 : xdim
                        temp += gradients4cell[offsets[c]+dof_i][k] * gradients4cell[offsets[c]+dof_j][k];
                    end
                end
                A[dofs_velocity[dof_i],dofs_velocity[dof_j]] += temp * nu * qf.w[i] * FE_velocity.grid.volume4cells[cell];
            end
            # pressure x div velocity
            for dof_j = 1 : ndofs4cell_pressure
                temp = 0.0;
                for c = 1 : xdim
                    temp -= gradients4cell[offsets[c]+dof_i][c];
                end    
                temp *= pressure_vals[i][dof_j] * coefficients_pressure[dof_j] * qf.w[i] * FE_velocity.grid.volume4cells[cell];
                A[dofs_velocity[dof_i],dofs_pressure[dof_j]] += temp;
                A[dofs_pressure[dof_j],dofs_velocity[dof_i]] += temp;
            end
        end    
        
        # Lagrange multiplier for integral mean
        
        for dof_i = 1 : ndofs4cell_pressure
                temp = pressure_vals[i][dof_i] * coefficients_pressure[dof_i] * qf.w[i] * FE_velocity.grid.volume4cells[cell];
                A[dofs_pressure[dof_i],ndofs + 1] += temp;
                A[ndofs + 1, dofs_pressure[dof_i]] += temp;
        end
      end  
    end
    #end  
end


function solveStokesProblem!(val4dofs::Array,nu::Real,volume_data!::Function,boundary_data!,grid::Grid.Mesh,FE_velocity::FiniteElements.AbstractFiniteElement,FE_pressure::FiniteElements.AbstractFiniteElement,quadrature_order::Int, use_reconstruction::Bool = false, dirichlet_penalty::Float64 = 1e60)
    
    
    ndofs_velocity = FiniteElements.get_ndofs(FE_velocity);
    ndofs_pressure = FiniteElements.get_ndofs(FE_pressure);
    ndofs = ndofs_velocity + ndofs_pressure;
    
    println("\nSOLVING STOKES PROBLEM")
    println(" |FEvelocity = " * FE_velocity.name)
    println(" |FEpressure = " * FE_pressure.name)
    println(" |totalndofs = ", ndofs)
    println(" |");
    println(" |PROGRESS")
    
    # assemble system 
    @time begin
        print("    |assembling matrix...")
        A = ExtendableSparseMatrix{Float64,Int64}(ndofs+1,ndofs+1) # +1 due to Lagrange multiplier for integral mean
        assemble_Stokes_Operator4FE!(A,nu,FE_velocity,FE_pressure);
        println("finished")
    end
        
    @time begin
        # compute right-hand side vector
        print("    |assembling rhs...")
        b = zeros(Float64,ndofs);
        if use_reconstruction
            @assert FiniteElements.Hdivreconstruction_available(FE_velocity)
            FE_Reconstruction = FiniteElements.get_Hdivreconstruction_space(FE_velocity);
            ndofsHdiv = FiniteElements.get_ndofs(FE_Reconstruction)
            b2 = zeros(Float64,ndofsHdiv);
            FESolveCommon.assemble_rhsL2!(b2, volume_data!, FE_Reconstruction, quadrature_order)
            println("finished")
            print("    |Hdivreconstruction...")
            T = ExtendableSparseMatrix{Float64,Int64}(ndofs_velocity,ndofsHdiv)
            FiniteElements.get_Hdivreconstruction_trafo!(T,FE_velocity);
            b[1:ndofs_velocity] = T*b2;
        else
            FESolveCommon.assemble_rhsL2!(b, volume_data!, FE_velocity, quadrature_order)
        end    
        println("finished")
    end
    
     # add value for Lagrange multiplier for integral mean
    if length(val4dofs) == ndofs
        append!(val4dofs,0.0);
        append!(b,0.0); # add value for Lagrange multiplier for integral mean
    end
    
    # apply boundary data
    bdofs = FESolveCommon.computeDirichletBoundaryData!(val4dofs,FE_velocity,boundary_data!,true);
    for i = 1 : length(bdofs)
       A[bdofs[i],bdofs[i]] = dirichlet_penalty;
       b[bdofs[i]] = val4dofs[bdofs[i]]*dirichlet_penalty;
    end
    @assert maximum(bdofs) <= ndofs_velocity

    @time begin
        print("    |solving...")
        try
            val4dofs[:] = A\b;
        catch    
            println("Unsupported Number type for sparse lu detected: trying again with dense matrix");
            try
                val4dofs[:] = Array{typeof(FE_velocity.grid.coords4nodes[1]),2}(A)\b;
            catch OverflowError
                println("OverflowError (Rationals?): trying again as Float64 sparse matrix");
                val4dofs[:] = Array{Float64,2}(A)\b;
            end
        end
        println("finished")
    end
    
    # compute residual (exclude bdofs)
    residual = A*val4dofs - b
    residual[bdofs] .= 0
    residual = norm(residual);
    println("    |residual=", residual)
    
    return residual
end


end
