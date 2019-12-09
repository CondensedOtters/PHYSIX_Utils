GPfolder=string("/home/moogmt/PHYSIX_Utils/GPlib/Julia/")
push!(LOAD_PATH, GPfolder)

# Loading necessary stuff
using atom_mod
using cell_mod
using cube_mod
using clustering
using contact_matrix
using filexyz
using graph
using exp_data
using geom

V=9.1
T=3000

folder_in = string("/media/moogmt/Elements/CO2/",V,"/",T,"K/")
file_traj = string(folder_in,"TRAJEC_wrapped.xyz")

traj,test = filexyz.readFastFile(file_traj)
cell = cell_mod.Cell_param(V,V,V)
cut_off=1.75

matrix = contact_matrix.buildMatrix( traj[1], cell, cut_off )
molecules=graph.getGroupsFromMatrix(matrix)
nb_molecules=size(molecules)[1]
matrices=graph.extractAllMatrixForTrees( matrix, molecules )
adjacent_molecule=getAllAdjacentVertex(matrices[1])

function unWrapOrtho!( positions::Array{T1,2}, origin::T2, target::T3, cell::T4  ) where { T1 <: Real, T2 <: Int, T3 <: Int, T4 <: Cell_param }
    for i=1:3
        dist=(positions[origin,i]-positions[target,i])
        if dist > cell.length[i]*0.5
            positions[target,i] += cell.length[i]
        elseif dist < -cell.length[i]*0.5
            positions[target,i] -= cell.length[i]
        end
    end
    return
end


# Return two bools:
# - Is the molecule an infinite chain?
# - Was the chain exploration went ok?
function isInfiniteChain( visited::Vector{T1}, matrix::Array{T2,2}, adjacency_table::Vector{T3}, positions::Array{T4,2} , cell::T5, target::T6, index_atoms::Vector{T7}, cut_off::T8 ) where { T1 <: Int, T2 <: Real, T3 <: Any, T4 <: Real, T5 <: cell_mod.Cell_param, T6 <: Int, T7 <: Int, T8 <: Real }
    visited[target]=1
    nb_neighbor=size(adjacency_table[target])[1]
    for neigh=1:nb_neighbor
        if visited[adjacency_table[target][neigh]] == 0
            #print("Parcours_:",index_atoms[target]," ",index_atoms[adjacency_table[target][neigh]],"\n")
            unWrapOrtho!( positions, index_atoms[target], index_atoms[ adjacency_table[target][neigh] ], cell )
            if geom.distance( positions[ index_atoms[target], : ], positions[ index_atoms[ adjacency_table[target][neigh] ] , : ] ) > cut_off
                return false, false
            end
            isinf, isok = isInfiniteChain(visited,matrix,adjacency_table,positions,cell,adjacency_table[target][neigh],index_atoms,cut_off)
            # If infinite molecule is spotted, we stop
            if ! isok
                return true, false
            end
            if ! isinf
                return true, true
            end
        elseif geom.distance(positions[index_atoms[target],:],positions[ index_atoms[adjacency_table[target][neigh]] ,: ] ) > cut_off
            # Spotted infinite loop; stops the search
            return true, true
        end
    end
    return false, true
end


function recursiveExplorativeUnWrap( visited::Vector{T1}, matrix::Array{T2,2}, adjacency_table::Vector{T3}, positions::Array{T4,2} , cell::T5, target::T6, index_atoms::Vector{T7}, cut_off::T8 ) where { T1 <: Int, T2 <: Real, T3 <: Any, T4 <: Real, T5 <: cell_mod.Cell_param, T6 <: Int, T7 <: Int, T8 <: Real }
    print(index_atoms[target],"\n")
    visited[target]=1
    nb_neighbor=size(adjacency_table[target])[1]
    for neigh=1:nb_neighbor
        if visited[adjacency_table[target][neigh]] == 0
            #print("Parcours_:",index_atoms[target]," ",index_atoms[adjacency_table[target][neigh]],"\n")
            unWrapOrtho!( positions, index_atoms[target], index_atoms[ adjacency_table[target][neigh] ], cell )
            if geom.distance( positions[ index_atoms[target], : ], positions[ index_atoms[ adjacency_table[target][neigh] ] , : ] ) > cut_off
                print("Err_:",index_atoms[target]," ",index_atoms[adjacency_table[target][neigh]],"\n")
                print("distance: ",geom.distance( positions[ index_atoms[target], : ], positions[ index_atoms[ adjacency_table[target][neigh] ] , : ] ),"\n")
                return -2
            end
            test = recursiveExplorativeUnWrap(visited,matrix,adjacency_table,positions,cell,adjacency_table[target][neigh],index_atoms,cut_off)
            # If infinite molecule is spotted, we stop
            if test < 0
                return test
            end
        elseif geom.distance(positions[index_atoms[target],:],positions[ index_atoms[adjacency_table[target][neigh]] ,: ] ) > cut_off
            # Spotted infinite loop; stops the search
            return -1
        end
    end
    return 1
end

start=molecules[1][1]
visited=zeros(Int,nb_atoms)
positions_local=copy(traj[1].positions)

nb_atoms=size(traj[1].names)[1]

test=recursiveExplorativeUnWrap(visited,matrices[1],adjacent_molecule,positions_local,cell,1,molecules[1],cut_off)

folder_out=string(folder_in)
file_out=string(folder_out,"test.xyz")
f_o=open(file_out,"w")
Base.write(f_o,string(nb_atoms,"\nTEST\n"))
for i=1:nb_atoms
    Base.write(f_o,string("N "))
    for j=1:3
        Base.write(f_o,string(positions_local[ i, j ]," "))
    end
    Base.write(f_o,string("\n"))
end
close(f_o)

folder_out=string(folder_in)
file_out=string(folder_out,"compare.xyz")
f_o=open(file_out,"w")
Base.write(f_o,string(nb_atoms,"\nTEST\n"))
for i=1:nb_atoms
    Base.write(f_o,string("O "))
    for j=1:3
        Base.write(f_o,string(traj[1].positions[ i, j ]," "))
    end
    Base.write(f_o,string("\n"))
end
close(f_o)

for molecule=1:nb_molecules
end


matrices=graph.extractAllMatrixForTrees(matrix,molecules)
