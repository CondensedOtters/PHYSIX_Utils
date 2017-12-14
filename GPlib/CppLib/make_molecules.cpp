//---------------
// External Libs
//-------------------
#include <fstream>
#include <iterator>
#include <iostream>
#include <vector>
#include <string>
#include <stdio.h>  
#include <stdlib.h>    
#include <math.h>
//---------------------

//----------------
// Internal Files
//-------------------------
#include "utils.h"
#include "atom.h"
#include "cell.h"
#include "contact_matrix.h"
#include "xyz.h"
#include "histogram.h"
#include "pdb.h"
#include "sim.h"
#include "lut.h"
#include "molecules.h"
//-------------------------

//================
// MAIN PROGRAM
//=====================================================================
int main( void )
{
  //--------
  // Input
  //---------------------------------
  std::ifstream input("TRAJEC.xyz");
  //---------------------------------

  //--------
  // Output
  //--------------------------------------------------------------------------------
  std::ofstream graph_molecules ( "graph_molecules.dat" ,  std::ios::out );
  std::ofstream hist_molecules ( "hist_molecules.dat" ,  std::ios::out );
  //-------------------------------------------------------------------------------
  std::ofstream co2_stock_in_out ( "co2_stock_in_out.dat" ,  std::ios::out );
  std::ofstream co3_stock_in_out ( "co3_stock_in_out.dat" ,  std::ios::out );
  std::ofstream co4_stock_in_out ( "co4_stock_in_out.dat" ,  std::ios::out );
  //-------------------------------
  std::ofstream co2_stock_in_time ( "co2_stock_in_time.dat" ,  std::ios::out );
  std::ofstream co3_stock_in_time ( "co3_stock_in_time.dat" ,  std::ios::out );
  std::ofstream co4_stock_in_time ( "co4_stock_in_time.dat" ,  std::ios::out );
  //-------------------------------
  std::ofstream co2_stock_alone_out ( "co2_stock_alone_out.dat" ,  std::ios::out );
  std::ofstream co3_stock_alone_out ( "co3_stock_alone_out.dat" ,  std::ios::out );
  std::ofstream co4_stock_alone_out ( "co4_stock_alone_out.dat" ,  std::ios::out );
  //-------------------------------
  std::ofstream co2_stock_alone_time ( "co2_stock_alone_time.dat" ,  std::ios::out );
  std::ofstream co3_stock_alone_time ( "co3_stock_alone_time.dat" ,  std::ios::out );
  std::ofstream co4_stock_alone_time ( "co4_stock_alone_time.dat" ,  std::ios::out );
  //-------------------------------------------------------------------------------
  //  RATIOS
  //-------------------------------------------------------------------------------
  std::ofstream co2_ratio_out ( "c2_ratio_out.dat" ,  std::ios::out );
  std::ofstream co2_ratio_time ( "co2_ratio_time.dat" , std::ios::out );
  std::ofstream co3_ratio_out ( "c3_ratio_out.dat" ,  std::ios::out );
  std::ofstream co3_ratio_time ( "co3_ratio_time.dat" , std::ios::out );
  std::ofstream co4_ratio_out ( "c4_ratio_out.dat" ,  std::ios::out );
  std::ofstream co4_ratio_time ( "co4_ratio_time.dat" , std::ios::out );
  //-------------------------------------------------------------------------------
  // DISTANCE FROM PLAN
  //-------------------------------------------------------------------------------
  std::ofstream distance_from_plan( "distance_from_plan.dat" , std::ios::out );
  std::ofstream distance_from_plan_in( "distance_from_plan_in.dat" , std::ios::out );
  std::ofstream distance_from_plan_alone( "distance_from_plan_alone.dat" , std::ios::out );
  std::ofstream distance_from_plan_hist_alone( "distance_from_plan_hist_alone.dat" , std::ios::out );
  std::ofstream distance_from_plan_hist_in( "distance_from_plan_hist_in.dat" , std::ios::out );
  std::ofstream dfp_in_r1_time( "dfp_in_r1_time.dat" , std::ios::out );
  std::ofstream dfp_in_r2_time( "dfp_in_r2_time.dat" , std::ios::out );
  std::ofstream dfp_alone_r1_time( "dfp_alone_r1_time.dat" , std::ios::out );
  std::ofstream dfp_alone_r2_time( "dfp_alone_r2_time.dat" , std::ios::out );
  std::ofstream dfp_in_r1_hist( "dfp_in_r1_hist.dat" , std::ios::out );
  std::ofstream dfp_in_r2_hist( "dfp_in_r2_hist.dat" , std::ios::out );
  std::ofstream dfp_alone_r1_hist( "dfp_alone_r1_hist.dat" , std::ios::out );
  std::ofstream dfp_alone_r2_hist( "dfp_alone_r2_hist.dat" , std::ios::out );
  std::ofstream dfp_in_r1_1th_hist( "dfp_in_r1_1th_hist" , std::ios::out );
  std::ofstream dfp_in_r1_2th_hist( "dfp_in_r1_2th_hist" , std::ios::out );
  std::ofstream dfp_in_r1_3th_hist( "dfp_in_r1_3th_hist" , std::ios::out );
  std::ofstream dfp_in_r1_4th_hist( "dfp_in_r1_4th_hist" , std::ios::out );
  std::ofstream dfp_in_r1_5th_hist( "dfp_in_r1_5th_hist" , std::ios::out );
  std::ofstream dfp_in_r2_1th_hist( "dfp_in_r2_1th_hist" , std::ios::out );
  std::ofstream dfp_in_r2_2th_hist( "dfp_in_r2_2th_hist" , std::ios::out );
  std::ofstream dfp_in_r2_3th_hist( "dfp_in_r2_3th_hist" , std::ios::out );
  std::ofstream dfp_in_r2_4th_hist( "dfp_in_r2_4th_hist" , std::ios::out );
  std::ofstream dfp_in_r2_5th_hist( "dfp_in_r2_5th_hist" , std::ios::out );
  std::ofstream dfp_alone_r1_1th_hist( "dfp_alone_r1_1th_hist" , std::ios::out );
  std::ofstream dfp_alone_r1_2th_hist( "dfp_alone_r1_2th_hist" , std::ios::out );
  std::ofstream dfp_alone_r1_3th_hist( "dfp_alone_r1_3th_hist" , std::ios::out );
  std::ofstream dfp_alone_r1_4th_hist( "dfp_alone_r1_4th_hist" , std::ios::out );
  std::ofstream dfp_alone_r1_5th_hist( "dfp_alone_r1_5th_hist" , std::ios::out );
  std::ofstream dfp_alone_r2_1th_hist( "dfp_alone_r2_1th_hist" , std::ios::out );
  std::ofstream dfp_alone_r2_2th_hist( "dfp_alone_r2_2th_hist" , std::ios::out );
  std::ofstream dfp_alone_r2_3th_hist( "dfp_alone_r2_3th_hist" , std::ios::out );
  std::ofstream dfp_alone_r2_4th_hist( "dfp_alone_r2_4th_hist" , std::ios::out );
  std::ofstream dfp_alone_r2_5th_hist( "dfp_alone_r2_5th_hist" , std::ios::out );
  //--------------------------------------------------------------------------------
  
  //----------------------
  // Physical parameters
  //--------------------------------------
  int step       = 1;  // Step counter
  int start_step = 2000; // Start step
  int end_step   = 1000000; // End step
  int comp_step  = 1; // Frequency of computation
  //--------------------------------------

  //---------------
  // Initializers
  //--------------------------------------------------
  AtomList  atom_list;  // Atoms in cell
  AllTypeLUT lut_list; // LUT for types
  ContactMatrix cm_connection;    // Contact Matrix
  ContactMatrix cm_distance;    // Contact Matrix
  //--------------------------------------------------

  //------
  // Data
  //-----------------------------------------
  std::vector<double> co2_data;
  std::vector<double> sizes;
  //-------------------------------------
  int co2_in = 0, co2_alone = 0; std::vector<double> co2_stock_in; std::vector<double> co2_stock_alone; std::vector<double> co2_ratio; 
  //-------------------------------------
  int co3_in = 0, co3_alone = 0; std::vector<double> co3_stock_in; std::vector<double> co3_stock_alone; std::vector<double> co3_ratio; 
  //-------------------------------------
  int co4_in = 0, co4_alone = 0; std::vector<double> co4_stock_in; std::vector<double> co4_stock_alone; std::vector<double> co4_ratio;
  //-------------------------------------
  std::vector<double> dfp_in_r1 , dfp_in_r2 , dfp_alone_r1 , dfp_alone_r2;
  std::vector<double> dfp_in_r1_1th , dfp_in_r2_1th, dfp_alone_r1_1th, dfp_alone_r2_1th;
  std::vector<double> dfp_in_r1_2th , dfp_in_r2_2th, dfp_alone_r1_2th, dfp_alone_r2_2th;
  std::vector<double> dfp_in_r1_3th , dfp_in_r2_3th, dfp_alone_r1_3th, dfp_alone_r2_3th;
  std::vector<double> dfp_in_r1_4th , dfp_in_r2_4th, dfp_alone_r1_4th, dfp_alone_r2_4th;
  std::vector<double> dfp_in_r1_5th , dfp_in_r2_5th, dfp_alone_r1_5th, dfp_alone_r2_5th;
  // Distance From Plan
  std::vector<double> distPlanC3 , distPlanC3_in, distPlanC3_alone ;
  //----------------------------------------------------------------------

  //--------------
  // Atom Indexes
  //-------------------------
  std::vector<int> atom_indexesC;
  std::vector<int> atom_indexesO;
  //-------------------------

  
  //-----------
  // Histogram
  //-----------------------------------------
  // Sizes
  double hist_start       = 0.5,     hist_end = 96.5;
  double hist_start_ratio = -0.001 , hist_end_ratio = 1.05;
  double hist_co2_start   = -0.001 , hist_co2_end = 1.05;
  int nb_box_ratio = 200 , nb_box = 96, nb_box2 = 1000, nb_co2_box = 200;
  std::vector<Bin> hist, hist_co2;
  //-----------------------------------------

  //--------------------
  // Reading Cell File
  //-------------------------------------------------------------------
  Cell cell;
  if ( ! readParamCell( "cell.param" , cell ) )
    {
      return 1;
    }
  //-------------------------------------------------------------------

  //-----------------
  // Reading Cut-Off
  //-------------------------------------------------------------------
  CutOffMatrix cut_off;
  if ( ! readCutOff( "cut_off.dat" , cut_off , lut_list ) )
    {
      return 1;
    }
  //-------------------------------------------------------------------

  //-------------------
  // Reading XYZ file
  //----------------------------------------------------
  while( readStepXYZfast( input , atom_list , lut_list, true, true ) )
    {
      if ( step % comp_step == 0 && step > start_step && step < end_step)
	{

	  //---------------------------
       	  // Makes the contact matrix
	  //----------------------------------------------------
	  makeContactMatrix( cm_connection , cm_distance , atom_list, cell , cut_off , lut_list );
	  //----------------------------------------------------

	  //-------
	  // Index
	  //---------------------------------------------------
	  atom_indexesC = cm_distance.lut_list.types[0].atom_index;
	  atom_indexesO = cm_distance.lut_list.types[1].atom_index;
	  //---------------------------------------------------
	  
	  //------------------
	  // Making molecules
	  //----------------------------------------------------
	  std::vector<Molecule> molecules = makeMolecules( cm_connection );
	  //----------------------------------------------------
	  
	  //-----------------
	  // Reinitialialize
	  //----------------------------------------------------
	  co2_in = 0, co2_alone = 0;
	  co3_in = 0, co3_alone = 0;
	  co4_in = 0, co4_alone = 0;
	  //----------------------------------------------------
	  
	  //-------------------------------------------------------
	  // Calculating ratios co2/co3/co4 + Distance From Plan
	  //-----------------------------------------------------------------------------
	  for ( int i=0 ; i < molecules.size() ; i++  )
	    {
	      for ( int j=0 ; j < molecules[i].atom_index.size() ; j++ )
		{
		  std::vector<double> angles = getAngleAtom( cm_distance , molecules[i] , molecules[i].atom_index[j] );
		  if ( angles.size() == 0 ) continue;
		  if ( molecules[i].names[j] == "C" )
		    {
		      if ( angles.size() == 1 )
			{
			  if ( molecules[j].names.size() == 3 )
			    {
			      co2_alone++;
			    }
			  else co2_in++;
			}
		      else if ( angles.size() == 3 )
			{
			  std::vector<int> per_atoms_index = getBonded( molecules[i] , molecules[i].atom_index[j] );
			  int index_center = molecules[i].atom_index[j];
			  std::vector<double> position_center = getMinImage( atom_list , cell , index_center , index_center );
			  std::vector<double> position_atom1  = getMinImage( atom_list , cell , index_center , per_atoms_index[0] );
			  std::vector<double> position_atom2  = getMinImage( atom_list , cell , index_center , per_atoms_index[1] );
			  std::vector<double> position_atom3  = getMinImage( atom_list , cell , index_center , per_atoms_index[2] );
			  std::vector<double> vector_plan1 = difference( position_atom1 , position_atom2 ) ;
			  std::vector<double> vector_plan2 = difference( position_atom1 , position_atom3 ) ;
			  double dist = getDistanceFromPlan( vector_plan1 , vector_plan2 , position_center , position_atom1 );
			  if ( molecules[j].names.size() == 4 )
			    {
			      distance_from_plan_alone << step << " " << dist << std::endl;
			      if ( dist > 0)
				{
				  if ( dist < 0.35 )
				    {
				      dfp_alone_r1_time << step << " " << dist << std::endl;
				      dfp_alone_r1.push_back( dist );
				      dfp_alone_r1_1th.push_back( getNNearest( cm_distance , 1 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r1_2th.push_back( getNNearest( cm_distance , 2 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r1_3th.push_back( getNNearest( cm_distance , 3 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r1_4th.push_back( getNNearest( cm_distance , 4 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r1_5th.push_back( getNNearest( cm_distance , 5 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				    }
				  else
				    {
				      dfp_alone_r2_time << step << " " << dist << std::endl;
				      dfp_alone_r2.push_back( dist );
				      dfp_alone_r2_1th.push_back( getNNearest( cm_distance , 1 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r2_2th.push_back( getNNearest( cm_distance , 2 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r2_3th.push_back( getNNearest( cm_distance , 3 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r2_4th.push_back( getNNearest( cm_distance , 4 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_alone_r2_5th.push_back( getNNearest( cm_distance , 5 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				    }
				}
			      distPlanC3_alone.push_back( dist );
			      co3_alone++;
			    }
			  else
			    {
			      distance_from_plan_in << step << " " << dist << std::endl;
			      if ( dist > 0)
				{
				  if ( dist < 0.35 )
				    {
				      dfp_in_r1_time << step << " " << dist << std::endl;
				      dfp_in_r1.push_back( dist );
				      dfp_in_r1_1th.push_back( getNNearest( cm_distance , 1 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r1_2th.push_back( getNNearest( cm_distance , 2 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r1_3th.push_back( getNNearest( cm_distance , 3 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r1_4th.push_back( getNNearest( cm_distance , 4 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r1_5th.push_back( getNNearest( cm_distance , 5 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				    }
				  else
				    {
				      dfp_in_r2_time << step << " " << dist << std::endl;
				      dfp_in_r2.push_back( dist );
				      dfp_in_r2_1th.push_back( getNNearest( cm_distance , 1 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r2_2th.push_back( getNNearest( cm_distance , 2 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r2_3th.push_back( getNNearest( cm_distance , 3 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r2_4th.push_back( getNNearest( cm_distance , 4 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				      dfp_in_r2_5th.push_back( getNNearest( cm_distance , 5 , atom_indexesC , atom_indexesO )[molecules[i].atom_index[j]] );
				    }
				}
			      distPlanC3_in.push_back( dist );
			      co3_in++;
			    }
			}
		      else if ( angles.size() == 6 )
			{
			  if ( molecules[j].names.size() == 5 )
			    {
			      co4_alone++;
			    }
			  else co4_in++;
			}
		    }
		}
	    }
	  //-----------------------------------------------------------------------------

	  int c_total = co2_in + co3_in + co4_in + co2_alone + co3_alone + co4_alone;
	  
	  //-----------------------------
	  // Stocking sizes of molecules
	  //----------------------------------------------------------
	  // Molecule alone
	  //------------------------------
	  // Storing co2/co3/co4
	  co2_stock_in.push_back( (double)(co2_in)/(double)(c_total) );
	  co3_stock_in.push_back( (double)(co3_in)/(double)(c_total) );
	  co4_stock_in.push_back( (double)(co4_in)/(double)(c_total) );
	  // Putting co2/co3/co4 to file
	  co2_stock_in_time << step << " " << (double)(co2_in)/(double)(c_total) << std::endl;
	  co3_stock_in_time << step << " " << (double)(co3_in)/(double)(c_total) << std::endl;
	  co4_stock_in_time << step << " " << (double)(co4_in)/(double)(c_total) << std::endl;
	  //------------------------------
	  // Molecule bigger
	  //------------------------------
	  // Storing co2/co3/co4
	  co2_stock_alone.push_back( (double)(co2_alone)/(double)(c_total) );
	  co3_stock_alone.push_back( (double)(co3_alone)/(double)(c_total) );
	  co4_stock_alone.push_back( (double)(co4_alone)/(double)(c_total) );
	  // Putting co2/co3/co4 to file
	  co2_stock_alone_time << step << " " << (double)(co2_alone)/(double)(c_total) << std::endl;
	  co3_stock_alone_time << step << " " << (double)(co3_alone)/(double)(c_total) << std::endl;
	  co4_stock_alone_time << step << " " << (double)(co4_alone)/(double)(c_total) << std::endl;
	  //-------------------------------------------------------------------

	  //--------
	  // RATIOS
	  //--------------------------------------------------------------------
	  // CO2
	  int co2_total = co2_alone + co2_in;
	  if ( co2_total != 0 ) co2_ratio.push_back( (double)(co2_alone)/(double)(co2_total) );
	  else co2_ratio.push_back( 0 );
	  // CO3
	  int co3_total = co3_alone + co3_in;
	  if ( co3_total != 0 ) co3_ratio.push_back( (double)(co3_alone)/(double)(co3_total) );
	  else co3_ratio.push_back( 0 );
	  // CO4
	  int co4_total = co4_alone + co4_in;
	  if ( co4_total !=  0 ) co4_ratio.push_back( (double)(co4_alone)/(double)(co4_total) );
	  else co4_ratio.push_back( 0 );
	  //--------------------------------------------------------------------

	  //-------------
	  // Step making
	  //----------------------------------------------------
	  std::cout << step << std::endl;
	  //----------------------------------------------------
	  
	}      
      step++;
     }
  //----------------------------------------------------

  //------------------
  // % co2 Histogram 
  //-------------------------------------------------------
  // larger molecule
  writeHistogram( co2_stock_in_out , normalizeHistogram( makeRegularHistogram( co2_stock_in , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  writeHistogram( co3_stock_in_out , normalizeHistogram( makeRegularHistogram( co3_stock_in , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  writeHistogram( co4_stock_in_out , normalizeHistogram( makeRegularHistogram( co4_stock_in , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  // molecule alone
  writeHistogram( co2_stock_alone_out , normalizeHistogram( makeRegularHistogram( co2_stock_alone , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  writeHistogram( co3_stock_alone_out , normalizeHistogram( makeRegularHistogram( co3_stock_alone , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  writeHistogram( co4_stock_alone_out , normalizeHistogram( makeRegularHistogram( co4_stock_alone , hist_co2_start, hist_co2_end, nb_co2_box ) ) );
  // ratios
  writeHistogram( co2_ratio_out , normalizeHistogram( makeRegularHistogram( co2_ratio , min( co2_ratio) , max( co2_ratio) , nb_box ) ) );
  writeHistogram( co3_ratio_out , normalizeHistogram( makeRegularHistogram( co3_ratio , min( co3_ratio) , max( co3_ratio) , nb_box ) ) );
  writeHistogram( co4_ratio_out , normalizeHistogram( makeRegularHistogram( co4_ratio , min( co4_ratio) , max( co4_ratio) , nb_box ) ) );
  // Distances from plan
  /*writeHistogram( distance_from_plan_hist_alone , normalizeHistogram( makeRegularHistogram( distPlanC3_alone , -0.0001 , max( distPlanC3_alone ), nb_box ) ) );
  writeHistogram( distance_from_plan_hist_in , normalizeHistogram( makeRegularHistogram( distPlanC3_in , -0.0001 , max( distPlanC3_alone ), nb_box ) ) );
  writeHistogram( dfp_in_r1_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1 , min(  dfp_in_r1 ) , max( dfp_in_r1 ) , nb_box ) ) );
  writeHistogram( dfp_in_r2_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2 , min(  dfp_in_r2 ) , max( dfp_in_r2 ) , nb_box ) ) );
  writeHistogram( dfp_alone_r1_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1 , min( dfp_alone_r1 ) , max( dfp_alone_r1 ), nb_box ) ) );
  writeHistogram( dfp_alone_r2_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2 , min( dfp_alone_r2 ) , max( dfp_alone_r2 ), nb_box ) ) );*/
  //----------------------------------------------
  std::cout << "check1th " << dfp_in_r1_1th.size()<< std::endl;
  std::cout << "check2th " << dfp_in_r1_2th.size()<< std::endl;
  std::cout << "check3th " << dfp_in_r1_3th.size()<< std::endl;
  std::cout << "check4th " << dfp_in_r1_4th.size()<< std::endl;
  std::cout << "check5th " << dfp_in_r1_5th.size()<< std::endl;
  std::cout << "check" << std::endl;
  writeHistogram( dfp_in_r1_1th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1_1th , min( dfp_in_r1_1th ) , max( dfp_in_r1_1th ), nb_box ) ) );
  std::cout << "check" << std::endl;
  writeHistogram( dfp_in_r1_2th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1_2th , min( dfp_in_r1_2th ) , max( dfp_in_r1_2th ), nb_box ) ) );
    std::cout << "check" << std::endl;
  writeHistogram( dfp_in_r1_3th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1_3th , min( dfp_in_r1_3th ) , max( dfp_in_r1_3th ), nb_box ) ) );
  std::cout << "check" << std::endl;
  writeHistogram( dfp_in_r1_4th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1_4th , min( dfp_in_r1_4th ) , max( dfp_in_r1_4th ), nb_box ) ) );
  std::cout << "check" << std::endl;
  writeHistogram( dfp_in_r1_5th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r1_5th , min( dfp_in_r1_5th ) , max( dfp_in_r1_5th ), nb_box ) ) );
  //----------------------------------------------
  /*
  writeHistogram( dfp_in_r2_1th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2_1th , min( dfp_in_r2_1th ) , max( dfp_in_r2_1th ), nb_box ) ) );
  writeHistogram( dfp_in_r2_2th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2_2th , min( dfp_in_r2_2th ) , max( dfp_in_r2_2th ), nb_box ) ) );
  writeHistogram( dfp_in_r2_3th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2_3th , min( dfp_in_r2_3th ) , max( dfp_in_r2_3th ), nb_box ) ) );
  writeHistogram( dfp_in_r2_4th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2_4th , min( dfp_in_r2_4th ) , max( dfp_in_r2_4th ), nb_box ) ) );
  writeHistogram( dfp_in_r2_5th_hist , normalizeHistogram( makeRegularHistogram( dfp_in_r2_5th , min( dfp_in_r2_5th ) , max( dfp_in_r2_5th ), nb_box ) ) );
    //----------------------------------------------
  writeHistogram( dfp_alone_r1_1th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1_1th , min( dfp_alone_r1_1th ) , max( dfp_alone_r1_1th ), nb_box ) ) );
  writeHistogram( dfp_alone_r1_2th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1_2th , min( dfp_alone_r1_2th ) , max( dfp_alone_r1_2th ), nb_box ) ) );
  writeHistogram( dfp_alone_r1_3th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1_3th , min( dfp_alone_r1_3th ) , max( dfp_alone_r1_3th ), nb_box ) ) );
  writeHistogram( dfp_alone_r1_4th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1_4th , min( dfp_alone_r1_4th ) , max( dfp_alone_r1_4th ), nb_box ) ) );
  writeHistogram( dfp_alone_r1_5th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r1_5th , min( dfp_alone_r1_5th ) , max( dfp_alone_r1_5th ), nb_box ) ) );
    //----------------------------------------------
  writeHistogram( dfp_alone_r2_1th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2_1th , min( dfp_alone_r2_1th ) , max( dfp_alone_r2_1th ), nb_box ) ) );
  writeHistogram( dfp_alone_r2_2th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2_2th , min( dfp_alone_r2_2th ) , max( dfp_alone_r2_2th ), nb_box ) ) );
  writeHistogram( dfp_alone_r2_3th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2_3th , min( dfp_alone_r2_3th ) , max( dfp_alone_r2_3th ), nb_box ) ) );
  writeHistogram( dfp_alone_r2_4th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2_4th , min( dfp_alone_r2_4th ) , max( dfp_alone_r2_4th ), nb_box ) ) );
  writeHistogram( dfp_alone_r2_5th_hist , normalizeHistogram( makeRegularHistogram( dfp_alone_r2_5th , min( dfp_alone_r2_5th ) , max( dfp_alone_r2_5th ), nb_box ) ) );*/
  //-------------------------------------------------------
  
  //-----------------
  // Size histograms
  //---------------------------------------------------------
  for ( int i=0 ; i < hist.size() ; i++ )
    {
      hist[i].value = hist[i].value*center(hist[i]);
    }
  writeHistogram( hist_molecules , normalizeHistogram( makeRegularHistogram( sizes , hist_start , hist_end , nb_box ) ) );
  //----------------------------------------------------

  //--------------
  //Closing fluxes
  //----------------------
  input.close();
  graph_molecules.close();
  hist_molecules.close();
  //-----------------------
  // CO2/3/4
  //-----------------------
  co2_stock_in_out.close();
  co2_stock_in_time.close();
  co3_stock_in_out.close();
  co3_stock_in_time.close();
  co4_stock_in_out.close();
  co4_stock_in_time.close();
  //-----------------------
  co2_stock_alone_out.close();
  co2_stock_alone_time.close();
  co3_stock_alone_out.close();
  co3_stock_alone_time.close();
  co4_stock_alone_out.close();
  co4_stock_alone_time.close();
  //-----------------------
  // RATIO
  //-----------------------
  co2_ratio_out.close();
  co3_ratio_out.close();
  co4_ratio_out.close();
  //-----------------------
  // Distance from plan
  //-----------------------
  // Global
  // -  in
  distance_from_plan_in.close();
  distance_from_plan_hist_in.close();
  // - Alone
  distance_from_plan_alone.close();
  distance_from_plan_hist_alone.close();
  // Range1
  dfp_alone_r1_time.close();
  dfp_alone_r1_hist.close();
  dfp_in_r1_hist.close();
  // Range 2
  dfp_alone_r2_time.close();
  dfp_alone_r2_hist.close();
  dfp_in_r2_hist.close();
  //
  dfp_in_r1_1th_hist.close();
  dfp_in_r1_2th_hist.close();
  dfp_in_r1_3th_hist.close();
  dfp_in_r1_4th_hist.close();
  dfp_in_r1_5th_hist.close();
  dfp_in_r2_1th_hist.close();
  dfp_in_r2_2th_hist.close();
  dfp_in_r2_3th_hist.close();
  dfp_in_r2_4th_hist.close();
  dfp_in_r2_5th_hist.close();
  dfp_alone_r1_1th_hist.close();
  dfp_alone_r1_2th_hist.close();
  dfp_alone_r1_3th_hist.close();
  dfp_alone_r1_4th_hist.close();
  dfp_alone_r1_5th_hist.close();
  dfp_alone_r2_1th_hist.close();
  dfp_alone_r2_2th_hist.close();
  dfp_alone_r2_3th_hist.close();
  dfp_alone_r2_4th_hist.close();
  dfp_alone_r2_5th_hist.close();
  //----------------------
  
  return 0;
}
