GPfolder=string("/home/moogmt/PHYSIX_Utils/GPlib/Julia/")

include(string(GPfolder,"contactmatrix.jl"))

# Folder for data
folder_base="/media/moogmt/Stock/CO2/AIMD/Liquid/PBE-MT/"

# Thermo data
Volumes=[8.82,9.0,9.05,9.1,9.15,9.2,9.25,9.3,9.35,9.375,9.4,9.5,9.8,10.0]
Temperatures=[2000,2500,3000]
Cut_Off=[1.75]

# Number of atoms
nbC=32
nbO=nbC*2
max_coord=5

restart=false

V=8.82
T=3000
cut_off=1.75

folder_in=string(folder_base,V,"/",T,"K/")
file=string(folder_in,"TRAJEC_wrapped.xyz")

folder_out=string(folder_in,"Data/")

traj = filexyz.readFastFile(file)
cell=cell_mod.Cell_param(V,V,V)

nb_atoms=size(traj[1].names)[1]
nb_steps=size(traj)[1]

restart=true

coord_matrix=zeros(nb_steps,nbC,8)

file_out=open(string(folder_out,"coordinance-C-",cut_off,".dat"),"w")
for step_sim=1:nb_steps

    print("Progress: ",step_sim/nb_steps*100,"%\n")
    write(file_out,string(step_sim," "))
    bond_matrix=zeros(nb_atoms,nb_atoms)
    for atom1=1:nb_atoms
        for atom2=atom1+1:nb_atoms
            if cell_mod.distance(traj[step_sim],cell,atom1,atom2) < cut_off
                bond_matrix[atom1,atom2]=1
                bond_matrix[atom2,atom1]=1
            end
        end
    end
    for carbon=1:nbC
        coord_matrix[step_sim,carbon,1]=sum(bond_matrix[carbon,1:nbC])
        coord_matrix[step_sim,carbon,2]=sum(bond_matrix[carbon,nbC+1:nbC+nbO])
        write(file_out,string(sum(bond_matrix[carbon,1:nbC])," ",sum(bond_matrix[carbon,nbC+1:nbC+nbO])," ") )
    end
    write(file_out,string("\n"))
end
close(file_out)

guess_cases=false
case_matrix=zeros(Int,nb_steps,nbC)

cases=zeros(38,8)
cases[1,:]=[-1,-1,-1,-1,1,1,-1,-1]
cases[2,:]=[-1,-1,-1,-1,2,1,-1,-1]
cases[3,:]=[-1,-1,-1,-1,2,2,2,-1]
cases[4,:]=[-1,-1,-1,-1,2,2,1,-1]
cases[5,:]=[-1,-1,-1,-1,2,1,1,-1]
cases[6,:]=[-1,-1,-1,-1,1,1,1,-1]
cases[7,:]=[-1,-1,-1,-1,2,2,2,2]
cases[8,:]=[-1,-1,-1,-1,2,2,2,1]
cases[9,:]=[-1,-1,-1,-1,2,2,1,1]
cases[10,:]=[-1,-1,-1,-1,2,1,1,1]
cases[11,:]=[-1,-1,-1,-1,1,1,1,1]
cases[12,:]=[2,-1,-1,-1,2,-1,-1,-1]
cases[13,:]=[2,-1,-1,-1,1,-1,-1,-1]
cases[14,:]=[3,-1,-1,-1,2,-1,-1,-1]
cases[15,:]=[3,-1,-1,-1,1,-1,-1,-1]
cases[16,:]=[4,-1,-1,-1,2,-1,-1,-1]
cases[17,:]=[4,-1,-1,-1,1,-1,-1,-1]
cases[18,:]=[2,-1,-1,-1,2,2,-1,-1]
cases[19,:]=[2,-1,-1,-1,2,1,-1,-1]
cases[20,:]=[2,-1,-1,-1,1,1,-1,-1]
cases[21,:]=[3,-1,-1,-1,2,2,-1,-1]
cases[22,:]=[3,-1,-1,-1,2,1,-1,-1]
cases[23,:]=[3,-1,-1,-1,1,1,-1,-1]
cases[24,:]=[4,-1,-1,-1,2,2,-1,-1]
cases[25,:]=[4,-1,-1,-1,2,1,-1,-1]
cases[26,:]=[4,-1,-1,-1,1,1,-1,-1]
cases[27,:]=[2,-1,-1,-1,2,2,2,-1]
cases[28,:]=[2,-1,-1,-1,2,2,1,-1]
cases[29,:]=[2,-1,-1,-1,2,1,1,-1]
cases[30,:]=[2,-1,-1,-1,1,1,1,-1]
cases[31,:]=[3,-1,-1,-1,2,2,2,-1]
cases[32,:]=[3,-1,-1,-1,2,2,1,-1]
cases[33,:]=[3,-1,-1,-1,2,1,1,-1]
cases[34,:]=[3,-1,-1,-1,1,1,1,-1]
cases[35,:]=[4,-1,-1,-1,2,2,2,-1]
cases[36,:]=[4,-1,-1,-1,2,2,1,-1]
cases[37,:]=[4,-1,-1,-1,2,1,1,-1]
cases[38,:]=[4,-1,-1,-1,1,1,1,-1]

count_cases=zeros(38)

file_out=open(string(folder_out,"cases_simple-",cut_off,"-extended.dat"),"w")
for step_sim=1:nb_steps
    print("Computing cases - Progress: ",step_sim/nb_steps*100,"%\n")
    global count_cases
    for carbon=1:nbC
        global index=1
        i=1
        global d=0
        for k=1:size(cases)[2]
            global d+= (coord_matrix[step_sim,carbon,k] - cases[i,k])*(coord_matrix[step_sim,carbon,k] - cases[i,k])
        end
        global d_min=d
        for i=2:size(cases)[1]
            global d=0
            for k=1:size(cases)[2]
                global d+= (coord_matrix[step_sim,carbon,k] - cases[i,k])*(coord_matrix[step_sim,carbon,k] - cases[i,k])
            end
            if d < d_min
                global index=i
                global d_min=d
            end
        end
        count_cases[index] += 1
        case_matrix[step_sim,carbon]=index
    end
end
close(file_out)

lag_min=1
d_lag=10
lag_max=5001
case_transition=zeros(Float64,size(cases)[1],size(cases)[1],Int(trunc((lag_max-lag_min)/d_lag)))
global count_lag=1
for lag=lag_min:d_lag:lag_max-1
    print("Lag Compute - Progress: ",lag/lag_max*100,"%\n")
    for carbon=1:nbC
        for step_sim=lag+1:nb_steps
            case_transition[ case_matrix[step_sim-lag,carbon], case_matrix[step_sim,carbon], count_lag ] += 1
        end
    end
    global count_lag += 1
end
