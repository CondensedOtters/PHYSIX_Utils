#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Jan 18 21:31:51 2020

@author: moogmt

The goal here is to provide an in-depth analysis of CO2 under extreme conditions 
using a combination of:
    - Very potent local descriptor with the Smooth Overlap of Atomic Positions (SOAP)
    - A Feed-Forward Neural Network 
    - Markov State Models
    
Here are dealing with a highly reactive polymeric fluid where bonds are not easily
described. 

The code functions as follows:
    - We first label all carbons depending on their bonding coordination:
    carbon that have neighbors in the contentious region (1.6 < d < 2) are 
    excluded and the remaining carbons are labeled depending on the number of
    neighbors that they have (C/O separately)
    - We then construct simple first and second layer atomic states
    - The first two steps are repeated with oxygen
    - SOAP descriptors are then computed for all atoms, and the resulting
    vectors are separated into a training and test set and fed to a NN that
    aims at giving them the proper label. Incase some labels are too weak, they 
    are bootstrapped so that there is no distribution issue.
    - The same procedure is followed with a SVM machine for classification and
    results are compared
    - The best procedure is then used to label the C/O that could not be labelled
    earlier. A handshake is used to make sure that the labellign give consistent 
    results. If not a more clever method should be used.
    - Second layers states are then computed and and used as reference for a 
    Markov State Model.
    - If the results are conclusive, the lifetime of states are computed
    for each states and if possible the mean first passage time from each structure
    to each other as well.
    - Each state is characterized as a chemical active site and the lengths and angles
    dsitrbutions are computed.
"""

import nnmetadata as mtd
import filexyz as xyz
import cpmd 
import descriptors as desc
import numpy as np

data_base  = "/home/moogmt/CO2/"

verbose_check=True # Whether we want error messages 
debug = False # Debug mode: verbose descriptions are written in a debug file
# in order to check everything


# EXTRACTING DATA
#=============================================================================#
volume=8.82
temperature=3000 
run_nb=1
folder_in = data_base + str(run_nb) + "-run/"
folder_out = data_base + "Data/"
file_traj = folder_in + "TRAJEC_db.xyz"
#-----------------------------------------------------------------------------
# Reading trajectory
stride_ = 1
traj = xyz.readPbcCubic( file_traj, volume )
traj = traj[0:len(traj):stride_]
periodic = True
# add a check to verify congruence of sizes...
# Getting species present in the simulation
n_atoms = len(traj[0])
species = mtd.getSpecies(traj[0])
n_species = len(species)
#traj=mtd.sortAtomsSpecie(traj) # Use if you need to sort the atoms per type, current implementation is *very* slow
species_sorted=True
start_species=mtd.getStartSpecies( traj, species )
nb_element_species=mtd.getNbAtomsPerSpecies( traj, species )
#=============================================================================#

# Keeping only easily identifiable carbons
#=============================================================================#
import ase.geometry as asegeom

step=0

file_2C = open( data_base + str("2C.dat"), "w" )
file_3C = open( data_base + str("3C.dat"), "w" )
file_4C = open( data_base + str("4C.dat"), "w" )

file_2O = open( data_base + str("2O.dat"), "w" )
file_3O = open( data_base + str("3O.dat"), "w" )



# Build descriptors from positions (train set only)
sigma_  = 0.3  # 3*sigma ~ 2.7A relatively large spread
cutoff_ = 3.5 # cut_off SOAP, 
nmax_   = 3
lmax_   = 3
distances=asegeom.get_distances(traj[step].positions, pbc=traj[step].pbc,cell=traj[step].cell )[1]
soaps = desc.createDescriptorsSingleSOAP( traj[step], species, sigma_, cutoff_, nmax_, lmax_, periodic )

cut_off = 1.75
cut_low = 1.6
cut_high = 1.9


to_ignore_mask = np.array([ sum ( (distances[atom,:] > cut_low) & (distances[atom,:] < cut_high )) for atom in range(n_atoms) ]) < 1
label_naive = np.array( [ sum( distances[atom,:]  < cut_off )-1 for atom in range(n_atoms) ] )
max_neighbours = np.amax( [sum( distances[ atom, : ] < cut_low ) for atom in range(n_atoms)] )

mask_label = np.empty((max_neighbours+1,n_atoms),dtype=bool)
for nb_neigh in range(0,max_neighbours+1):
    mask_label[ nb_neigh, : ] = [ sum( distances[atom,:] < cut_low )-1 == nb_neigh for atom in range(n_atoms) ] & ~to_ignore_mask



file_2C.close()
file_3C.close()
file_4C.close()

file_2O.close()
file_3O.close()


descriptorC=desc.createDescriptorsSOAP( traj[step], species, sigma_, cutoff_, nmax_, lmax_, periodic )[0:32][index_[0:32],:]
descriptorO=desc.createDescriptorsSOAP( traj[step], species, sigma_, cutoff_, nmax_, lmax_, periodic )[0:32][index_[0:32],:]


#=============================================================================#

import matplotlib.pyplot as plt
  

