module cpmd

using conversion

export readInputTimestep, readIntputStrideStress, readIntputStrideTraj
export readEnergy, readPressure, readStress, readTRAJ

# Read input
# Reads the input file of a CPMD simuation
#==============================================================================#
function readInputTimestep( file_input_path::T1 ) where { T1 <: AbstractString }
    # Read input
    file_in=open(file_input_path)
    lines=readlines(file_in)
    close(file_in)

    # Extract timestep
    timestep=0
    nb_lines=size(lines)[1]
    for line_nb=1:nb_lines
        keywords=split(lines[line_nb])
        if size(keywords)[1] > 0
            if keywords[1] == "TIMESTEP"
                timestep=parse(Float64,split(lines[line_nb+1])[1])
            end
        end
    end

    # Conversion to fs
    return conversion.hatime2fs*timestep
end
function readIntputStrideStress( file_input_path::T1 ) where { T1 <: AbstractString }
    # Readinput
    file_in=open(file_input_path)
    lines=readlines(file_in)
    close(file_in)

    # Extract stride of STRESS tensor
    stride_stress = 0
    nb_lines=size(lines)[1]
    for line_nb=1:nb_lines
        keywords=split(lines[line_nb])
        if size(keywords)[1] > 0
            if keywords[1] == "STRESS" && keywords[2] == "TENSOR"
                stride_stress = parse(Float64,split(lines[line_nb+1])[1])
            end
        end
    end

    return stride_stress
end
function readIntputStrideTraj( file_input_path::T1 ) where { T1 <: AbstractString }
    # Readinput
    file_in=open(file_input_path)
    lines=readlines(file_in)
    close(file_in)

    # Extract stride of STRESS tensor
    stride_traj = 0
    nb_lines=size(lines)[1]
    for line_nb=1:nb_lines
        keywords=split(lines[line_nb])
        if size(keywords)[1] > 0
            if keywords[1] == "TRAJECTORY"
                stride_traj = parse(Float64,split(lines[line_nb+1])[1])
            end
        end
    end

    return stride_traj
end
#==============================================================================#

# Read Output files
#==============================================================================#
# Reading ENERGIES file
# Contains: Temperature, Potential Energy, Total Energy, MSD and Computing time for each step
# Structure:
# 1 line per step, per column:
# time, temperature, potential energy, total energy, MSD, Computing time
function readEnergyFile( file_name::T1 ) where { T1 <: AbstractString }
    #--------------
    # Reading file
    #----------------------
    if ! isfile(file_name)
        return zeros(1,1),zeros(1,1),zeros(1,1),zeros(1,1),zeros(1,1), false
    end

    file=open(file_name);
    lines=readlines(file);
    close(file);
    #-----------------------

    # Array Init
    #----------------------------------------
    nb_steps=size(lines)[1]
    temperature=Vector{Real}(undef,nb_steps)
    e_class=Vector{Real}(undef,nb_steps)
    e_ks=Vector{Real}(undef,nb_steps)
    msd=Vector{Real}(undef,nb_steps)
    time=Vector{Real}(undef,nb_steps)
    #----------------------------------------

    # Getting data from lines
    #----------------------------------------------
    for i=1:nb_steps
        line=split(lines[i])
        temperature[i]=parse(Float64,line[3])
        e_ks[i]=parse(Float64,line[4])
        e_class[i]=parse(Float64,line[5])
        msd[i]=parse(Float64,line[7])
        time[i]=parse(Float64,line[8])
    end
    #----------------------------------------------

    return  temperature, e_ks, e_class, msd, time, true
end
# Reading STRESS file
# Contains: Stress tensor for each step (with a possible stride)
# Structure:
# 4 lines per step
# line 1: Comment (indicates step number)
# line 2-4: stress tensor in matrix form
# Sxx Sxy Sxz
# Syx Syy Syz
# Szx Szy Szz
function readStress( file_name::T1 ) where { T1 <: AbstractString, T2 <: Int }

    # Checking file exists
    if ! isfile(file_name)
        return zeros(1,1), false
    end
    # Reading file
    file=open(file_name);
    lines=readlines(file);
    close(file);

    # Le fichier est composés de blocs de 4 lignes:
    # 1 ligne pour le time step
    # 3 lignes pour le stress tensor
    nb_stress_points=Int(trunc(size(lines)[1]/4))
    stress=zeros(Real,nb_stress_points,3,3)
    offset=0
    for step=1:nb_stress_points
        for i=1:3
            keywords=split(lines[1+4*(step-1)+i+offset])
            if keywords[1] == "TOTAL"
                if offset == 1
                    print("DOUBLE SIM SPOTTED at step : ",step,"\n")
                    print("LINE: ",1+4*(step-1)+i+offset,"\n")
                    return zeros(1,1), false
                end
                offset += 1
            else
                for j=1:3
                    stress[step,i,j] = parse(Float64,keywords[j])
                end
            end
        end
    end

    return stress, true
end
function readStress( file_name::T1, stride::T2 ) where { T1 <: AbstractString, T2 <: Int }

    # Checking file exists
    if ! isfile(file_name)
        return zeros(1,1), false
    end

    # Reading file
    file=open(file_name);
    lines=readlines(file);
    close(file);

    # Creation de variables
    nb_stress_points=Int(trunc(size(lines)[1]/(4*stride)))
    stress=Array{Real}(nb_stress_points,3,3)
    offset=0
    # loop
    for step=1:nb_stress_points
        for i=1:3
            for j=1:3
                keywords=split(lines[1+4*(step-1)*stride+i+offset])
                if keywords[1] == "TOTAL"
                    if offset == 1
                        print("DOUBLE SIM SPOTTED at : ",step,"\n")
                        return zeros(1,1), false
                    end
                    offset+=1
                end
                stress[step,i,j] = parse(Float64,keywords[j])
            end
        end
    end
    #----------------------------------------------------------

    return stress,true
end
# Read FTRAJECTORY file
# Contains: positions, velocity and forces in atomic units for each step
# Structure:
# 1 line per atom per step
# Per line:
# atom_number x y z vx vy vz fx fy fz
function readFTRAJ( file_input::T1 ) where { T1 <: AbstractString }

    # cols (both files):
    #   0:   natoms x nfi (natoms x 1, natoms x 2, ...)
    #   1-3: x,y,z cartesian coords [Bohr]
    #   4-6: x,y,z cartesian velocites [Bohr / thart ]
    #        thart = Hartree time =  0.024189 fs
    # FTRAJECTORY extra:
    #   7-9: x,y,z cartesian forces [Ha / Bohr]

    nb_step,nb_atoms=getNbStepAtoms( file_input )

    file_in=open( file_input )
    lines=readlines( file_in )
    close(file_in)
    nb_lines=size(lines)[1]

    # new_string: <<<<<<  NEW DATA  >>>>>>
    check_new=string("<<<<<<")

    positions=zeros(nb_step,nb_atoms,3)
    velocity=zeros(nb_step,nb_atoms,3)
    forces=zeros(nb_step,nb_atoms,3)


    return positions,velocity,forces,atom_index,atom_types
end
#==============================================================================#

end
