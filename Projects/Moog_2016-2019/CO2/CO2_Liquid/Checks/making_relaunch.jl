GPfolder=string("/home/moogmt/LibAtomicSim/Julia/")
push!(LOAD_PATH, GPfolder)

# Aims at fixing stuff
using utils
using atom_mod
using cell_mod
using filexyz
using pdb
using conversion
using cpmd
using press_stress
using exp_data

Local_Params=string("/home/moogmt/PHYSIX_Utils/Projects/")
push!(LOAD_PATH, Local_Params )

using computerDB

#==============================================================================#
folder_base = utils.determineFolderPath( computerDB.computers_names, computerDB.computers_pathsCO2 )
if folder_base == false
    print("Computer is not known, add it to the database.")
    exit()
end
#==============================================================================#


# T,V
Volumes=[9.15,9.1,9.05,9.0,8.82,8.8,8.6]
Temperatures=[ 3000, 2500, 2000, 1750 ]

# Target Timestep
for V in Volumes
    for T in Temperatures
        run_=1
        check = true
        while check
            folder_target = string(folder_base,V,"/",T,"K/",run_,"-run/")
            if isdir(folder_target)
                if isfile( string(folder_target,"FLAG") )
                    cpmd.relaunchRunTrajec( folder_target, string(folder_target,"input_restart") )
                else
                    cpmd.relaunchRunFtraj( folder_target, string(folder_target,"input_restart") )
                end
                print("Ok for V:",V," T:",T,"K run:",run_,"\n")
                run_ += 1
            else
                check = false
            end
        end
    end
end