#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Dec 26 12:15:45 2019

@author:  julienh with modification from moogmt

Contains functions for handling data
"""

import numpy as np
import pandas as pd
import ase

# 
def choseTrainDataByIndex(metadata,structures,energies,chosen_index): 
    metadata['train_index'] = chosen_index
    if metadata['size_train_set'] == 0 :    
        metadata['size_train_set']=len(chosen_index)
    structuresAtoms=np.empty(metadata['size_train_set'],dtype=ase.atoms.Atoms)

    if type(structures[0]) != ase.atoms.Atoms :
        for i in range(metadata['size_train_set']) :
            structuresAtoms[i] = ase.atoms.Atoms(numbers=metadata['n_atoms'], positions=structures[i,:] )   
        return pd.DataFrame({"energy":energies,'structure':structuresAtoms})
    else
    energies = energies[chosen_index]
    return pd.DataFrame({"energy":energies,'structure':structures})

# 
def choseTrainDataRandom(metadata,structures,energies):    
    chosen_index = np.random.choice(metadata['total_size_set'],size=int(metadata['train_fraction']*metadata['total_size_set']),replace=metadata['replace'])
    print("chosen: ",chosen_index,"\n")
    return choseTrainDataByIndex(metadata,structures,energies,chosen_index)
