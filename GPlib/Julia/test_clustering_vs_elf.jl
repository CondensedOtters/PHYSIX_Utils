# Testing clustering against ELF

include("atoms.jl")
include("cell.jl")
include("cubefile.jl")

step_max=501
step_min=1
d_step=100

nbC=32
nbO=64

bond_matrix_truth=zeros(32,64,Int((step_max-step_min)/10))
distance_matrix=zeros(32,64,Int((step_max-step_min)/10))

test=zeros(Int,1)
test[1]=1
print("step_analysis: ",step_analysis,"\n")
for step=step_min:d_step:step_max
	print("Progress: ",step/step_max,"%\n")
	atoms, cell_matrix, elf = cube_mod.readCube(string("/home/moogmt/CO2/CO2_AIMD/ELF/ELF_8.82_results/",step,"_elf.cube"))
	params=zeros(3)
	for j=1:3
		for k=1:3
			params[j] += cell_matrix[j,k]^2
		end
		params[j] = sqrt(params[j])
	end
	cell=cell_mod.Cell_param(params[1],params[2],params[3])

	for atom=1:size(atoms.names)[1]
		for i=1:3
			atoms.positions[atom,i]=cell_mod.wrap(atoms.positions[atom,i],params[i])
		end
		atoms.positions[atom,:]-= elf.origin
	end
	for carbon=1:nbC
		for oxygen=1:nbO
			distance_matrix[carbon,oxygen,test[1]] = cell_mod.distance( atoms, cell, carbon, nbC+oxygen )
			if distance_matrix[carbon,oxygen,test[1]] < 3.0
				for j=1:3
				    di = atoms.positions[carbon,j]-atoms.positions[nbC+oxygen,j]
				    if di > cell.length[j]*0.5
					atoms.positions[nbC+oxygen,j] += cell.length[j]
				    end
				    if di < -cell.length[j]*0.5
					atoms.positions[nbC+oxygen,j] -= cell.length[j]
				    end
				end
				temp1=atoms.positions[carbon,:]
				temp2=atoms.positions[carbon,:]
				for i=1:3
					temp1[i]=cell_mod.wrap(atoms.positions[carbon,i],params[i])
					temp2[i]=cell_mod.wrap(atoms.positions[nbC+oxygen,i],params[i])
				end
				center=(atoms.positions[carbon,:]+atoms.positions[nbC+oxygen,:])/2.
				for i=1:3
					center[i]=cell_mod.wrap(center[i], params[i])
				end
				index=[0,0,0]
				for i=1:3
					check=center[i]*elf.nb_vox[i]/params[i]
				    	index[i]=trunc(check)
					if check - index[i] > 0.5
						index[i] += 1
					end
					if index[i] > elf.nb_vox[i]-1
						index[i]=0
					end
				end
				distance1=0
				for i=1:3
				    distance1+=cell_mod.dist1D( index[i]*cell.length[i]/elf.nb_vox[i], center[i], cell.length[i] )^2
				end
				for l=-1:1:1
					for m=-1:1:1
						for n=-1:1:1
							new_index=[0,0,0]
							new_index[1]=index[1]+l
							new_index[2]=index[2]+m
							new_index[3]=index[3]+n
							for l=1:3
						    		if new_index[l] < 0
									new_index[l] = elf.nb_vox[l] - new_index[l]
						    		end
						    		if new_index[l] >= elf.nb_vox[l]-1
									new_index[l] = new_index[l]-elf.nb_vox[l]
						    		end
							end
							distance2=0
							for i=1:3
						    		distance2+=cell_mod.dist1D( new_index[i]*cell.length[i]/elf.nb_vox[i], center[i], params[i] )^2
							end
							if distance2 < distance1
						    		distance1 = distance2
						    		index=new_index
							end
					    	end
					end
				end
				for i=1:3
					index[i] += 1
				end
				if elf.matrix[index[1],index[2],index[3]] > 0.7
					bond_matrix_truth[carbon,oxygen,test[1]] = 1
				end
			end
		end
	end
	test[1] = test[1]+1
end
