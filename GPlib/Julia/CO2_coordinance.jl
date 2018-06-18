# Loading file
include("contactmatrix.jl")
folder="/media/moogmt/Stock/CO2/AIMD/Liquid/PBE-MT/8.82/3000K/"
file=string(folder,"TRAJEC_wrapped.xyz")
atoms = filexyz.readFastFile(file)
cell=cell_mod.Cell_param(8.82,8.82,8.82)
nb_steps=size(atoms)[1]
nb_atoms=size(atoms[1].names)[1]
stride=5
unit=0.0005

coord=zeros(4,nb_steps)
for k=1:nb_steps
    for j=1:32
        for i=1:96
            if i != j
                dist=cell_mod.distance(atoms[k],cell,j,i)
                if dist < 1.8
                    coord[1,k] += 1
                    if dist < 1.75
                        coord[2,k] += 1
                        if dist < 1.70
                            coord[3,k] += 1
                            if dist < 1.6
                                coord[4,k] += 1
                            end
                        end
                    end
                end
            end
        end
    end
    coord[:,k] /= 32
end
using PyPlot
figure(1)
t=linspace(0, nb_steps*stride*unit, nb_steps)
plot(t,coord[4,:],"-")
plot(t,coord[3,:],"-")
plot(t,coord[2,:],"-")
plot(t,coord[1,:],"-")
legend(["rc=1.6","rc=1.7","rc=1.75","rc=1.8"])
xlabel("time(ps)")
ylabel("Average Coordinance")

file=open(string(folder,"coord_avg.dat"),"w")
for i=1:size(coord[1,:])[1]
    write(file,string(t[i]))
    write(file," ")
    for j=1:4
        write(file,string(coord[j,i]))
        write(file," ")
    end
    write(file,"\n")
end
close(file)


include("contactmatrix.jl")
folder="/media/moogmt/Stock/CO2/AIMD/Liquid/PBE-MT/8.82/3000K/"
file=string(folder,"TRAJEC_wrapped.xyz")
atoms = filexyz.readFastFile(file)
cell=cell_mod.Cell_param(8.82,8.82,8.82)
nb_steps=size(atoms)[1]
nb_atoms=size(atoms[1].names)[1]
stride=5
unit=0.0005


stride2=1
file_matrix=open(string(folder,"coord18.dat"),"w")
coord_check=zeros(nb_atoms)
time_hist=[]
timeC_hist=[]
timeO_hist=[]
timeCother_hist=[]
timeC2_hist=[]
timeC3_hist=[]
timeC4_hist=[]
timeO1_hist=[]
timeO2_hist=[]
timeOother_hist=[]
time=zeros(nb_atoms)
for i=1:stride2:nb_steps
    coord=zeros(nb_atoms)
    write(file_matrix,string(i*stride2*stride*unit," "))
    # Computing BondMatrix
    matrix18=contact_matrix.computeMatrix(atoms[i],cell,1.8)
    # Computing coordinance
    #---------------------------
    for j=1:nb_atoms
        coord[j] = 0
        for k=1:nb_atoms
            if j != k
                if matrix18[j,k] > 0.0000001
                    coord[j] += 1
                end
            end
        end
        write(file_matrix,string(coord[j]," "))
    end
    #---------------------------
    # Computing averages
    #----------------------------------------------------------------------------
    avgC=0
    avgO=0
    for j=1:32
        avgC += coord[j]
    end
    avgAll=avgC
    avgC /= 32
    for j=33:96
        avgO += coord[j]
    end
    avgAll += avgO
    avgO /= 64
    avgAll /= nb_atoms
    write(file_matrix,string(avgC," ",avgO," ",avgAll,"\n"))
    #---------------------------------------------------------------------------
    if i > 1
        for j=1:nb_atoms
            if abs(coord[j] - coord_check[j]) > 0.0000001
                time[j] += 1
                time2=time[j]*stride2*stride*unit
                if j < 33
                    push!(timeC_hist,time2)
                    if coord_check[j] == 2
                        push!(timeC2_hist,time2)
                    elseif coord_check[j] == 3
                        push!(timeC3_hist,time2)
                    elseif coord_check[j] == 4
                        push!(timeC4_hist,time2)
                    else
                        push!(timeCother_hist,time2)
                    end
                else
                    push!(timeO_hist,time2)
                    if coord_check[j] == 1
                        push!(timeO1_hist,time2)
                    elseif coord_check[j] == 2
                        push!(timeO2_hist,time2)
                    else
                        push!(timeOother_hist,time2)
                    end
                end
                push!(time_hist,time2)
                time[j] = 0
            else
                time[j] += 1
            end
        end
    end
    coord_check=coord
    print("step:",i,"\n")
end
close(file_matrix)


function makeHistogram4( data, nb_box)
    # getting max
    max=data[1]
    min=data[1]
    for i=2:size(data)[1]
        if data[i] > max
            max=data[i]
        end
        if data[i] < min
            min=data[i]
        end
    end
    hist=zeros(nb_box,2)
    size_box=(max-min)/nb_box
    for i=1:nb_box
        boxmin=min+(i-1)*size_box
        boxmax=boxmin+size_box
        hist[i,1]=boxmin+size_box/2.
        for j=1:size(data)[1]
            if data[j] > boxmin
                if data[j] < boxmax
                    hist[i,2] += 1
                end
            end
        end
    end
    sum=0
    for i=1:size(hist)[1]
        sum+=hist[i,2]
    end
    hist[:,2] /= sum
    return hist
end

using PyPlot
dataC=makeHistogram4(timeC_hist,200)
dataO=makeHistogram4(timeO_hist,200)
out=open(string(folder,"lifeC_hist.dat"),"w")
close(out)
figure(1)
plot(dataC[:,1],dataC[:,2],"r.")
plot(dataO[:,1],dataO[:,2],"b.")
legend(["C","O"])
xlim([0,0.3])
xlabel("Lifetime (ps)")
ylabel("Frequency")

dataC2=makeHistogram4(timeC2_hist,200)
dataC3=makeHistogram4(timeC3_hist,200)
dataC4=makeHistogram4(timeC4_hist,200)
figure(10)
plot(dataC2[:,1],dataC2[:,2],"r-.")
plot(dataC3[:,1],dataC3[:,2],"b-.")
plot(dataC4[:,1],dataC4[:,2],"g-.")
xlim([0,0.4])
legend(["C2","C3","C4"])
xlabel("Lifetime (ps)")
ylabel("Frequency")

dataO1=makeHistogram4(timeO1_hist,200)
dataO2=makeHistogram4(timeO2_hist,200)
figure(6)
plot(dataO1[:,1],dataO1[:,2],"r-.")
plot(dataO2[:,1],dataO2[:,2],"b-.")
xlim([0,0.3])
legend(["O1","O2"])
xlabel("Lifetime (ps)")
ylabel("Frequency")

figure(7)
plot(dataC2[:,1],dataC2[:,2],"r.-")
plot(dataC3[:,1],dataC3[:,2],"b.-")
plot(dataC4[:,1],dataC4[:,2],"g.-")
plot(dataO1[:,1],dataO1[:,2],"rd-")
plot(dataO2[:,1],dataO2[:,2],"cd-")
xlim([0,0.3])
legend(["C2","C3","C4","O1","O2"])
xlabel("Lifetime (ps)")
ylabel("Frequency")

nb_box=500
dataC=makeHistogram4(timeC_hist,nb_box)
dataO=makeHistogram4(timeO_hist,nb_box)
dataC2=makeHistogram4(timeC2_hist,nb_box)
dataC3=makeHistogram4(timeC3_hist,nb_box)
dataC4=makeHistogram4(timeC4_hist,nb_box)
dataO1=makeHistogram4(timeO1_hist,nb_box)
dataO2=makeHistogram4(timeO2_hist,nb_box)
function averageVar{ T1 <: Real }( data::Array{T1} )
    avg=0
    var=0
    for i=1:size(data)[1]
        avg += data[i,1]*data[i,2]
        var += (data[i,1]^2.)*data[i,2]
    end
    return avg, var
end

datC=averageVar(dataC)
datO=averageVar(dataO)
datC2=averageVar(dataC2)
datC3=averageVar(dataC3)
datC4=averageVar(dataC4)
datO1=averageVar(dataO1)
datO2=averageVar(dataO2)