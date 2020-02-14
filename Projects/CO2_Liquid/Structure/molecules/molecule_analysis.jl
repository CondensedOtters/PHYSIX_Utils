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

function writeMolecule( handle_out::T1 , positions::Array{T2}, species::Vector{T3}, step::T4, mol_index::T5 ) where { T1 <: IO, T2 <: Real,  T3 <: AbstractString, T4 <: Int, T5 <: Int }
    size_molecule=size(positions)[1]
    Base.write( handle_out, string( size_molecule, "\n" ) )
    Base.write( handle_out, string( step," ", mol_index, "\n" ) )
    for atom=1:size_molecule
        Base.write(species[atom], " ")
        for i=1:3
            Base.write( handle_out, string( positions[atom,i], " " ) )
        end
        Base.write( handle_out, string("\n") )
    end
    return true
end

# Thermodynamical values
Volumes=[10.0,9.8,9.5,9.4,9.375,9.35,9.325,9.3,9.25,9.2,9.15,9.1,9.05,9.0,8.82,8.8,8.6]
Temperature=[1750,2000,2500,3000,3500]
cut_off=1.75

V=8.82
T=3000


folder_base=string("/media/mathieu/Elements/CO2/",V,"/",T,"K/")

file_traj = string(folder_base,"TRAJEC_fdb_wrapped.xyz")

traj = filexyz.readFileAtomList( file_traj )
cell = cell_mod.Cell_param(V,V,V)
cut_off=1.75

nb_step=size(traj)[1]

handle_mol_inf = open( folder_target, "mol_inf.xyz")
handle_mol_fin = open( folder_target, "mol_fin.xyz")

for step=1:nb_step

    # Computing the molecules through graph exploration
    positions_local=copy(traj[step].positions)
    matrix = contact_matrix.buildMatrix( traj[step], cell, cut_off )
    molecules=graph.getGroupsFromMatrix(matrix)
    nb_molecules=size(molecules)[1]
    matrices=graph.extractAllMatrixForTrees( matrix, molecules )

    # Loop over mmolecules
    for molecule=1:nb_molecules
        # Molecule is an atom, discard
        if size(molecules[molecule])[1] <= 1
            continue
        end
        # Check if molecule is finite
        isinf, isok = isInfiniteChain( visited::Vector{T1}, matrix::Array{T2,2}, adjacency_table::Vector{T3}, positions::Array{T4,2} , cell::T5, target::T6, index_atoms::Vector{T7}, cut_off::T8 )
        # If something went wrong, moving on...
        if ! isok
            print( "Issue reconstructing molecule ", molecule, " at step: ", step, "\n" )
            continue
        end
        # Whether infinite or finite, the size of the molecule is counted, and it is printed in a specific file
        if isinf
            writeMolecule( handle_mol_inf, positions, species, step, molecule ) # write molecule
            # If the molecule is infinite, we print the atoms that should be bonded but aren't.
            list = findUnlinked( positions )
            # We put the positions of those atoms in a specific file, for visualization purposes (with VMD)
            writeMolecule( handle_mol_inf_link, positions[list,:], species, step, molecule ) # write links
            # Counting sizes
            hist_inf[ size_molecule ] += 1
        else
            writeMolecule( handle_mol_fin, positions, species, step, molecule ) # write molecule
            # Counting sizes
            hist_fin[ size_molecule ] += 1
        end
        hist_gen[ size_molecule ] += 1
        # NB: here we only count the molecule by size, hwoever that isn't fair, as a large molecule may take the
        # totality of the atoms. Therefore, a corrective factor will be needed when computing fair statistics.

    end

    traj[step].positions=positions_local
end

close( handle_mol_inf )
close( handle_mol_fin )