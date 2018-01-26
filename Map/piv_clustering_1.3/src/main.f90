! TODO : bottleneck in piv loop is the sorting!!
!------------------------------------------------------------------------------------------!
!MAIN                                                                                          !
!------------------------------------------------------------------------------------------!
program clustering_dmsd
#ifdef MPI
  use clustering_mod
  use mpi
  implicit none
  integer :: mpierror, mpisize, mpirank
#else
  use clustering_mod
  implicit none
  integer :: mpisize=1, mpirank=0
#endif
  integer::sizeofshortint
#ifdef FOURBYTES
  parameter(sizeofshortint=4)
#else
  parameter(sizeofshortint=2)
#endif

  ! functions
  integer::get_N_lines
  double precision::coordination,coordination_fermi,shortint2real
  integer(kind=sizeofshortint)::real2shortint

  !related to basic I/O
  logical::proceed=.true.,restart_piv=.false., restart_matrix=.false., network_analysis=.false.
  integer::progress_bar,progress_tot,n_record,argcount,lapack_err,in_filetype,ios,pbc_type
  integer,parameter::read101=101,read104=104,write201=201,write202=202,write204=204,svu_write=500,svu_write2=2000,svu_write3=3000
  character(len=500)::format_1,format_2,format_3,format_4,tmp_char,tmp_char2,svf_name,svf_basename='PIV_CORE.',in_file,out_file,wq_char
  character(len=80),allocatable,dimension(:)::comments
  character(len=4),allocatable,dimension(:)::spec,spec0
  character(len=80)::line
  logical::found

  !Limitations
  integer::ARRAY_SIZE=100E+06 ! Arbitrary....
  integer::max_frames

  !parameters
  integer::method,algorithm=1,coordtype=0
  logical::sort=.true., do_rdf=.false.
  double precision::cutoff,cutoff2,cutoff_clcoeff
  double precision::coord_d0,coord_r0,x10p,x90p,f10p=0.1d0,f90p=0.9d0,l1,l2,coord_lambda
  integer::coord_m,coord_n
  double precision,parameter::max_sprint=100.d0, deg2pi=3.14159265358979d0/180.d0

  !system specifics
  integer::n_atoms,n_steps,n_dim=3,n_cryst1
  double precision::max_v,min_v,h(3,3),hi(3,3)
  double precision,dimension(3)::box_size
  double precision,allocatable,dimension(:,:,:)::atom_positions
  double precision,allocatable,dimension(:,:)::cell
  logical::in
  logical::rescale
  character(len=3),allocatable,dimension(:)::s,n2t
  integer::is,js,ns,max_s,ig,ng,max_g,max_gs,gsi,vec_size,np,iat
  integer,allocatable,dimension(:)::nat_spec
  integer,allocatable,dimension(:,:)::s2n
  integer,allocatable,dimension(:)::n2s,n2o,gs
  integer,allocatable,dimension(:,:)::s2g,g2s
  integer,allocatable,dimension(:,:,:)::n2g,g2n
  double precision,allocatable,dimension(:,:)::contacts
  double precision,dimension(200)::rdf,rdf_global
  double precision::rdf_n

  !piv
  double precision::d,s1(3),s2(3),ds(3)
  integer(kind=sizeofshortint),allocatable,dimension(:)::v_to_write,vint
  double precision,allocatable,dimension(:)::dr,v,vtmp,vsorted
  double precision,allocatable,dimension(:,:)::r

  !frame-to-frame "distance" matrix
  double precision::dmsd,distmax,dista,dista2
  integer::real_stepi,real_stepj,readnsteps
  integer(kind=sizeofshortint),allocatable,dimension(:,:)::reduced_piv1,reduced_piv2
  double precision,allocatable,dimension(:)::v1,v2
  double precision,allocatable,dimension(:,:)::frame2frame,frame2frame_save

  !clusters
  integer:: n_clusters,acs,tot_acs !acs stands for actual_cluster_size
  integer,allocatable,dimension(:)::cluster_centers
  double precision, allocatable, dimension(:)::clustering_coefficients(:)
  integer,allocatable,dimension(:)::cluster_size
  integer,allocatable,dimension(:,:)::cluster_members,cluster_link
  logical::linked
  double precision::dist_ij,dist_ik,dist_jk

  !iteratives and stuff 
  integer::i,j,k,l,m,n,ii,jj,kk,mm,nn
  double precision::tmpr
  logical::ok_invert
  double precision::volume, volume0
  ! debug: integer::tbeg,tend,tpbc=0,tsqr=0,tcoo=0,tbeg0,tend0,ttot=0,tall=0,tsor=0
  
#ifdef MPI
  call MPI_Init(mpierror)
  call MPI_Comm_size(MPI_COMM_WORLD, mpisize, mpierror)
  call MPI_Comm_rank(MPI_COMM_WORLD, mpirank, mpierror)
#endif

  !--------------------------------------
  ! Master Worker sends starting message
  !----------------------------------------------------------------------------
  if(mpirank.eq.0) then
     write(*,'(a)')      "===================================================="
     write(*,'(a)')      "===        P I V      C L U S T E R I N G        ==="
     write(*,'(a)')      "===================================================="
     write(*,'(a)')      " version 1.35 - G. A. Gallet and F. Pietrucci, 2014 "
     write(*,'(a)')      " please read and cite J.Chem.Phys.139,074101(2013)  "
     write(*,'(a,i4,a)') "            < running on",mpisize," procs >"
     write(*,*) ""
  endif
  !----------------------------------------------------------------------------

  ! Getting console argument
  argcount=IARGC()
  
  !-----------------------------
  ! If no argument, prints help
  !----------------------------------------------------------------------------
  if(argcount.eq.0) then
     ! Code to stop
     proceed=.false.
     ! Master worker sends help message
     if(mpirank.eq.0) then
        print'(a)', 'USAGE:'
        print'(a)', './piv_clustering.x -filexyz traj.xyz -bsize 12.1 8.2 10.4 -method 2 -coord1_range 1.0 4.0 -algorithm 50 ...'
        print'(a)', ''
        print'(a)', "[-filepdb          ] input trajectory file (pdb format, includes cell parameters)"
        print'(a)', "[-filexyz          ] input trajectory file (xyz format)"
        print'(a)', "[-bsize            ] orthorombic box sides a b c in angstrom (only for xyz format)"
        print'(a)', "[-out              ] prefix for output cluster files (default cluster?.xyz)"
        print'(a)', "[-array_size       ] size of the biggest array allocated by the program"
        print'(a)', "[-method           ] method used to compute the PIV 1: distance, 2: coordination, 3: sprint"
        print'(a)', "[-coord1_range     ] specify the two distances at which coordination = 0.9 and 0.1, respectively"
        print'(a)', "[-coord1_param     ] parameters d0 r0 of coordination function 1/(1+exp((d-d0)/r0)) (method 2 or 3)"
        print'(a)', "[-coord2_param     ] parameters d0 r0 m n of coordination function (1-x**m)/(1-x**n) with x=(d-d0)/r0 (method 2 or 3)"
        print'(a)', "[-nosort           ] specify if you do not want to enforce the permutation symmetry of identical atoms"
        print'(a)', "[-restart_piv      ] restart the PIV from PIV_CORE.?  (it requires the same number of cores!)"
        print'(a)', "[-restart_matrix   ] restart the matrix from FRAME_TO_FRAME.MATRIX (also skip the PIV computation)"
        print'(a)', "[-algorithm        ] clustering algorithm 1: Daura's, >1: kmedoids with the number indicating the number of clusters"
        print'(a)', "[-cutoff_daura     ] cutoff for Daura's algorithm"
        print'(a)', "[-cutoff_clcoeff   ] cutoff for computing the clustering coefficient"
        print'(a)', "[-network_analysis ] analyze the network formed by cluster centers, and plot it in network.svg"
        print'(a)', "[-rdf              ] save the total radial distribution function in file rdf.dat"
        print'(a)', "[-rescale          ] activates rescaling for phases with different volumes."
     endif
  endif
  ! If no argument, stops the program
  if(.not.proceed) then
#ifdef MPI
     call MPI_Finalize(mpierror)
#endif
     stop
  endif
  !----------------------------------------------------------------------------

  !---------
  ! Defaults
  !-------------------------------------------------------
  out_file='cluster'    ! Default output prefix for files
  cutoff_clcoeff=0.d0
  in_filetype=0
  rescale = .false.
  !-------------------------------------------------------

  !-----------------------
  ! Parse command options:
  !----------------------------------------------------------------------------
  ! Going over all arguments
  do i=1,argcount
     ! File Name of PDB (flag -filepdb)
     !------------------------------------------
     call getarg(i,wq_char)    
     if(index(wq_char,'-filepdb').ne.0)then
        if(in_filetype.eq.1)then
           print'(a)', 'ERROR: input file format is either xyz or pdb!'
           stop
        endif
        call getarg(i+1,wq_char)
        read(wq_char,*) in_file
        in_filetype=2
        pbc_type=2 ! generic cell
        cycle
     endif
     ! Getting name of file if xyz
     !----------------------------------------------------------------
     if(index(wq_char,'-filexyz').ne.0)then
        if(in_filetype.eq.2)then
           print'(a)', 'ERROR: input file format is either xyz or pdb!'
           stop
        endif
        call getarg(i+1,wq_char)
        read(wq_char,*) in_file
        in_filetype=1
        pbc_type=1 ! orthorombic cell
        cycle
     endif
     !----------------------------------------------------------------
     ! Getting box parameters if xyz files
     !----------------------------------------------------------------
     if(index(wq_char,'-bsize').ne.0)then
        if(in_filetype.eq.2)then
           print'(a)', 'ERROR: -bsize is employed only with xyz files !'
           stop
        endif
        call getarg(i+1,wq_char)
        read(wq_char,*)box_size(1)
        call getarg(i+2,wq_char)
        read(wq_char,*)box_size(2)
        call getarg(i+3,wq_char)
        read(wq_char,*)box_size(3)
        cycle
     endif
     ! Getting output prefix 
     !----------------------------------------------------------------      
     if(index(wq_char,'-out').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) out_file
        cycle
     endif
     ! Get limitation on the size of the array 
     !----------------------------------------------------------------      
     if(index(wq_char,'-array_size').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) ARRAY_SIZE
        cycle
     endif
     ! Getting the method to be used for clustering
     !----------------------------------------------------------------      
     if(index(wq_char,'-method').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) method 
        cycle
     endif
     ! Getting distance range
     !----------------------------------------------------------------      
     if(index(wq_char,'-coord1_range').ne.0)then
        if(coordtype.eq.2) then
           print'(a)', 'ERROR: coord type 1 and 2 are mutually esclusive !'
           stop
        endif
        coordtype=1
        call getarg(i+1,wq_char)
        read(wq_char,*) x90p 
        call getarg(i+2,wq_char)
        read(wq_char,*) x10p
        l1=dlog((1.d0-f90p)/f90p)
        l2=dlog((1.d0-f10p)/f10p)
        coord_lambda=(l1-l2)/(x90p-x10p)
        coord_d0=x90p-l1/coord_lambda
        coord_r0=1.d0/coord_lambda
        cycle
     endif
     ! Getting coordinance 1 parameter and choosing it as method (exp)
     !---------------------------------------------------------------------        
     if(index(wq_char,'-coord1_param').ne.0)then
        if(coordtype.eq.2) then
           print'(a)', 'ERROR: coord type 1 and 2 are mutually esclusive !'
           stop
        endif
        coordtype=1
        call getarg(i+1,wq_char)
        read(wq_char,*) coord_d0
        call getarg(i+2,wq_char)
        read(wq_char,*) coord_r0
        coord_lambda=1.d0/coord_r0
        x10p=coord_d0+coord_r0*log(1.d0/f10p-1.d0)
        x90p=coord_d0+coord_r0*log(1.d0/f90p-1.d0)
        cycle
     endif
     ! Getting coordinance 2 parameters method and chosing it (sigmoid, fermi-dirac like function)
     !----------------------------------------------------------------------------------------------        
     if(index(wq_char,'-coord2_param').ne.0)then
        if(coordtype.eq.1) then
           print'(a)', 'ERROR: coord type 1 and 2 are mutually esclusive !'
           stop
        endif
        coordtype=2
        call getarg(i+1,wq_char)
        read(wq_char,*) coord_d0 
        call getarg(i+2,wq_char)
        read(wq_char,*) coord_r0 
        call getarg(i+3,wq_char)
        read(wq_char,*) coord_m 
        call getarg(i+4,wq_char)
        read(wq_char,*) coord_n 
        cycle
     endif
     ! Option to not sort the PIV vector (saves time...)
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-nosort').ne.0)then
        sort=.false.
        cycle
     endif
     ! Choosing clustering algorithm and if kmenoid, number of cluster to find
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-algorithm').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) algorithm
        if(algorithm.gt.1) then
           n_clusters=algorithm
           algorithm=2
        endif
        cycle
     endif
     ! Getting cut-off for daura cut-off method
     !----------------------------------------------------------------------------------------------        
     if(index(wq_char,'-cutoff_daura').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) cutoff 
        cycle
     endif
     ! Getting to cut-off for coefficent of matrix
     !----------------------------------------------------------------------------------------------        
     if(index(wq_char,'-cutoff_clcoeff').ne.0)then
        call getarg(i+1,wq_char)
        read(wq_char,*) cutoff_clcoeff 
        cycle
     endif
     ! Restarting PIV from unfinished calculation 
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-restart_piv').ne.0)then
        restart_piv=.true.
        cycle
     endif
     ! Restarting Matrix from unfinished calculation
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-restart_matrix').ne.0)then
        restart_piv=.true.
        restart_matrix=.true.
        cycle
     endif
     ! Doing network analysis ( 2d Projection using damped dynamics ) 
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-network_analysis').ne.0)then
        network_analysis=.true.
        cycle
     endif
     ! Chosing to compute rdf function
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-rdf').ne.0)then
        do_rdf=.true.
        rdf(:)=0.d0
        cycle
     endif
     ! Chosing rescale
     !----------------------------------------------------------------------------------------------        
     call getarg(i,wq_char)
     if(index(wq_char,'-rescale').ne.0)then
        rescale=.true.
        cycle
     endif
  enddo
  !--------------------------------------------------------------------------------------------------

  ! Checks that an input file was specified
  !----------------------------------------------------------------------------------------------        
  if(in_filetype.eq.0) then
     print'(a)', 'ERROR: you must specify an in input trajectory file!'
     stop
  endif
  !----------------------------------------------------------------------------------------------        

  ! Checks that a coordination function has been choosen (if method distance or SPRINT)
  !----------------------------------------------------------------------------------------------        
  if((method.eq.2.or.method.eq.3).and.(coordtype.eq.0)) then
     print'(a)', 'ERROR: with method = 2 or 3 you must specify a coordination function !'
     stop
  endif
  !----------------------------------------------------------------------------------------------        

  ! On master worker, prints options
  !---------------------------------------------------
  if(mpirank.eq.0) then
     write(*,'(a)') '-----------------------------------------------'
     if(in_filetype.eq.1) then
        write(*,'(a,a)')         '-filexyz           ',trim(in_file)
        write(*,'(a,3f9.3)')     '-bsize             ',box_size(1:3)
     else
        write(*,'(a,a)')         '-filepdb           ',trim(in_file)
     endif
     write(*,'(a,a)')         '-out               ',trim(out_file)
     write(*,'(a,i12)')       '-array_size        ',ARRAY_SIZE
     write(*,'(a,i1)')        '-method            ',method
     if(coordtype.eq.1) then
        write(*,'(a,2f8.4)')     '-coord1_param       ',coord_d0,coord_r0
     endif
     if(coordtype.eq.2) then
        write(*,'(a,2f8.4,2i3)') '-coord2_param       ',coord_d0,coord_r0,coord_m,coord_n 
     endif
     write(*,'(a,l)')         '-nosort            ',.not.sort
     write(*,'(a,i1)')        '-algorithm         ',algorithm
     write(*,'(a,f8.4)')      '-cutoff_daura      ',cutoff
     write(*,'(a,f8.4)')      '-cutoff_clcoeff    ',cutoff_clcoeff
     write(*,'(a,l)')         '-network_analysis  ',network_analysis
     write(*,'(a,l)')         '-restart_piv       ',restart_piv
     write(*,'(a,l)')         '-restart_matrix    ',restart_matrix
     write(*,'(a)') '-----------------------------------------------'
  endif
  !---------------------------------------------------

  ! Cut-off for matrix if coordinance
  !---------------------------------------------------
  if(algorithm.eq.2) cutoff=1.d10
  !---------------------------------------------------

  ! The master ranks prints information
  !_------------------------------------------------------------------------------
  if(mpirank.eq.0) then
     ! If using using distances
     !---------------------------------------------------
     if(method.eq.1) then
        print'(a)', 'computing the frame-to-frame distance matrix based on cartesian distances'
        ! If using coordinance
        !---------------------------------------------------
     elseif(method.eq.2) then
        print'(a)', 'computing the frame-to-frame distance matrix based on coordination function ='
        if(coordtype.eq.1) then
           print'(a,f5.2,a,f5.2,a,f5.2,a,f4.1,a,f5.2,a,f4.1)', '  f(d)=1/(1+exp((d-d0)/r0)) d0=',coord_d0,', r0=',coord_r0,' so that f(',x90p,')=',f90p,' and f(',x10p,')=',f10p
        endif
        if(coordtype.eq.2) then
           print'(a,f5.2,a,f5.2,a,i2,a,i2)', '  (1-x**m)/(1-x**n), x=(d-d0)/r0,  d0=',coord_d0,', r0=',coord_r0,', m=',coord_m,', n=',coord_n
        endif
        ! If method SPRINT
        !----------------------------
     elseif(method.eq.3) then
        print'(a)', 'computing the frame-to-frame distance matrix based on SPRINT, with coordination function ='
        if(coordtype.eq.1) then
           print'(a,f5.2,a,f5.2,a,f5.2,a,f4.1,a,f5.2,a,f4.1)', '  f(d)=1/(1+exp((d-d0)/r0)) d0=',coord_d0,', r0=',coord_r0,' so that f(',x90p,')=',f90p,' and f(',x10p,')=',f10p
        endif
        if(coordtype.eq.2) then
           print'(a,f5.2,a,f5.2,a,i2,a,i2)', '  (1-x**m)/(1-x**n), x=(d-d0)/r0,  d0=',coord_d0,', r0=',coord_r0,', m=',coord_m,', n=',coord_n
        endif
        !-------------------------------------
     else
        ! If method is different than 1,2 or 3, exit...
        print'(a)', 'ERROR: no such method'
        stop
     endif
     !--------------------------------------

     !-------------------------------------
     ! Print information about sorting PIV 
     !-----------------------------------------------------------------
     if(sort) then
        print'(a)', 'sorting the PIV to remove the permutation symmetry'
     else
        print'(a)', 'not sorting: clusters will distinguish equivalent structures with different labelling'
     endif
     !-----------------------------------------------------------------

     ! Print information about the clustering method
     !-----------------------------------------------------------------
     if(algorithm.eq.1) then
        print'(a,f10.6)', 'clustering with the daura algorithm: cutoff =',cutoff
     elseif(algorithm.eq.2) then
        print'(a,i4)', 'clustering with the kmedoids algorithm: N_clusters = ', N_clusters
     else
        print'(a)', 'ERROR: no such method for clustering'
        stop
     endif
     !-----------------------------------------------------------------

     ! Prints various informations
     !-----------------------------------------------------------------
     if(cutoff_clcoeff>0.d0) print'(a,f10.6)', 'cutoff for computation of clustering coefficients =',cutoff_clcoeff 
     if(restart_piv) print'(a)',"restarting with PIV in PIV.*"
     if(restart_matrix)   print'(a)',"restarting with the matrix in FRAME_TO_FRAME.MATRIX"
     if(network_analysis) print'(a)',"performing analysis of the network and printing file network.svg"
     !-----------------------------------------------------------------
  endif
  !-----------------------------------------------------------------

  !-------------------------
  ! Prints starting method
  !-----------------------------------------------------------------
  if(mpirank.eq.0) then
     write(*,*) 
     write(*,*) "*** initialization ***"
     write(*,*) 
  endif
  !-----------------------------------------------------------------

  ! Read trajectory with master worker
  !------------------------------------------------------------------
  if(mpirank.eq.0) write(*,*) "reading trajectory..."
  open(read101,file=in_file,status="old")
  ! Reads XYZ
  if (in_filetype.eq.1) then
     ! Get number of atoms
     !-----------------------
     read(read101,*),n_atoms
     !--------------------------
     ! Get number of lines
     !----------------------------
     n_steps=get_n_lines(read101)
     n_steps=n_steps/(n_atoms+2)
     !---------------------------
     ! Allocate vectors
     !-----------------------------------------------------------------------------------------
     allocate(atom_positions(n_steps,n_atoms,3),comments(n_steps),spec(n_atoms),spec0(n_atoms))
     !-----------------------------------------------------------------------------------------
     !      if(mpirank.eq.0) then
     do n=1,n_steps
        read(read101,*),
        read(read101,'(a)'),comments(n)
        do i=1,n_atoms
           read(read101,*), spec(i),(atom_positions(n,i,k),k=1,N_dim)
           if (n.eq.1) then
              spec0(i)=spec(i)
           else
              if (spec(i).ne.spec0(i)) then
                 write(*,*) "ERROR: mismatch of elements"
                 write(*,'(a,i9,a,i6,2x,a)') "frame ",1," : atom ",i,spec0(i)
                 write(*,'(a,i9,a,i6,2x,a)') "frame ",n," : atom ",i,spec(i)
                 write(*,*) "you must have the same sequence of elements in each frame"
                 stop
              endif
           endif
        enddo
     enddo
     !      endif
     ! Reads PDB
  elseif (in_filetype.eq.2) then ! ----- pdb
     ! format for each frame: CRYST1, MODEL, ATOM, CRYST1, MODEL, ATOM, ...
     ! Init steps, cell line, number of atoms, found?
     !-----------------------------------------------
     n_steps=0
     n_cryst1=0
     n_atoms=0
     found=.false.
     !----------------------------------------------
     ! Count the number of structures, steps and atoms
     !---------------------------------------------
     do
        read(read101,'(a80)',iostat=ios) line
        if (ios/=0) exit
        if (line(1:6).eq."CRYST1") n_cryst1=n_cryst1+1 ! number of crystal types...
        if (line(1:5).eq."MODEL") n_steps=n_steps+1    ! number of steps...
        if (line(1:4).eq."ATOM".and.n_steps.eq.1) n_atoms=n_atoms+1 ! number of atoms
     enddo
     !------------------------------------------------
     ! Check that the format is ok
     !------------------------------------------------
     if (mpirank.eq.0.and.n_cryst1.ne.n_steps) then
        write(*,*) "ERROR in pdb file: to each MODEL must correspond a CRYST1 (see manual)"
        stop
     endif
     !-------------
     ! Rewind file
     !----------------
     rewind(read101)
     !----------------
     !----------------------------
     ! Allocate all data vectors
     !----------------------------
     allocate(atom_positions(n_steps,n_atoms,3),comments(n_steps),spec(n_atoms),spec0(n_atoms),cell(n_steps,6))
     !----------------------------
     !      if(mpirank.eq.0) then
     n=0
     nn=0
     ! Read the files 
     do
        read(read101,'(a80)',iostat=ios) line
        if (ios/=0) exit
        if (line(1:6).eq."CRYST1") then
           nn=nn+1
           read(line(7:),*) cell(nn,1:6)
        endif
        if (line(1:5).eq."MODEL") then
           n=n+1
           read(line(6:),'(a)') comments(n)
           i=0
        endif
        if (line(1:4).eq."ATOM") then
           i=i+1      
           read(line(13:16),*) spec(i)
           read(line(31:54),*) (atom_positions(n,i,k),k=1,N_dim)
           if (n.eq.1) then
              spec0(i)=spec(i)
           else
              if (spec(i).ne.spec0(i)) then
                 write(*,*) "ERROR: mismatch of elements"
                 write(*,'(a,i9,a,i6,2x,a)') "frame ",1," : atom ",i,spec0(i)
                 write(*,'(a,i9,a,i6,2x,a)') "frame ",n," : atom ",i,spec(i)
                 write(*,*) "you must have the same sequence of elements in each frame"
                 stop
              endif
           endif
        endif
     enddo
     !      endif
  endif
  close(read101)

  ! Launch MPI broadcast of data
#ifdef MPI
  !    call MPI_Bcast(atom_positions,N_steps*N_atoms*N_dim,MPI_double_precision,0,MPI_COMM_WORLD,mpierror)
#endif

  !----------------------------------
  ! Prints number of atoms and steps
  !------------------------------------------------------
  if(mpirank.eq.0) then
     print '(a,a,i6,a,i8)', trim(in_file)," has N_atoms =",N_atoms," N_steps =",N_steps
  endif
  !------------------------------------------------------

  !--------------------------------------------------------------
  ! Compute size of vector (N*(N-1))/2 except for SPRINT where N
  !--------------------------------------------------------------
  if(method.eq.1 .or. method.eq.2 .or. method.eq.4)then
     vec_size=N_atoms*(N_atoms-1)/2 
  else
     vec_size=N_atoms
  endif
  !--------------------------------------------------------------

  !----------------------------------------------------
  ! Checks is matrix size is ok and prints information
  !-------------------------------------------------------------------------
  if(mpirank.eq.0) then
     ! If the size of the memory is too big, then use alternative slow method
     if( (N_steps*N_atoms*(N_atoms-1)/2.gt.ARRAY_SIZE) .and. (N_steps*N_steps).gt.ARRAY_SIZE) then
        ! Warning that the program is going slow or quit
        print'(a)', 'WARNING: You probably are going to run out of memory.. Stopping there !'
        ! Quitting
        stop
     endif
     ! Prints Matrix related stuff
     print '(a,i10,a,i10,a,i14)', 'PIV is going to be  ',N_steps,' x',vec_size,' =',N_steps*vec_size
     print '(a,i10,a,i10,a,i14)', 'frame-to-frame distance matrix is going to be     ',N_steps,' x',N_steps,' =',N_steps*N_steps
  endif
  !-------------------------------------------------------------------------

  !--------------------------------
  ! Compute max and min value in v
  !---------------------------------------------
  if(method.eq.1)then
     ! Min distance is 0
     min_v=0.d0
     if (pbc_type.eq.1) then
        ! If orthomrombic
        max_v=dsqrt(3.d0)*maxval(box_size)/2.d0
     else
        ! Else...
        max_v=sum(cell(n,1:3))/2.d0 ! empirical ...
     endif
  elseif(method.eq.2 .or. method.eq.4)then
     ! 1 - linked, 0 - not linked.
     min_v=0.d0
     max_v=1.d0
  elseif(method.eq.3)then
     ! SPRINT Method max
     min_v=0.d0
     max_v=max_sprint
  endif
  !---------------------------------------------

  !--------------------------------
  ! Get atomic species in the box
  !---------------------------------------------------
  max_s=N_atoms ! Maximum number of different species
  !---------------------------------------------------
  ! Allocate memory 
  !-----------------------------------------------------------------------------
  allocate(s(max_s))        ! Repertory of species for atoms
  allocate(nat_spec(max_s)) ! Vector containing number of atoms per species
  allocate(n2s(N_atoms))    ! Index of species 
  allocate(n2t(N_atoms))    ! Names of species
  allocate(s2n(max_s,N_atoms)) ! Specie Matrix?
  !-----------------------------------------------------------------------------

  !-------------------------------------
  ! Getting all different species in box
  !------------------------------------------------------
  nat_spec(:)=0 ! index specie
  ns=0          ! dummy var
  ! Loop over all atoms
  !------------------------------------------------------------------------------------
  do i=1,N_atoms
     
     !---------------------------
     ! Initialize existence flag
     !---------------------------
     in=.false.
     !---------------------------

     !----------------------------------------
     ! Loop over all already existing species
     !---------------------------------------------------
     do is=1,ns
        ! If specie already exists...
        if(s(is).eq.spec(i)) then
           ! Indicates that specie exists
           in=.true.
           ! Add index of atom to specie listing
           n2s(i)=is
           ! Add name of atom to specie listing
           n2t(i)=spec(i)
           ! Increments number of aton for that specie
           nat_spec(is)=nat_spec(is)+1
           ! Update Specie Matrix
           s2n(is,nat_spec(is))=i
        endif
     enddo
     !----------------------------------------------------

     !---------------------------
     ! If specie does not exists
     !-----------------------------------------
     if(.not. in ) then
        ! Increments the size
        ns=ns+1
        ! Add specie to specie listing
        s(ns)=spec(i)
        ! Add one label for new specie
        n2s(i)=ns
        ! Add name to specie listing
        n2t(i)=spec(i)
        ! Increment number of atom for that specie
        nat_spec(ns)=nat_spec(ns)+1
        ! Specie Matrix?
        s2n(ns,nat_spec(ns))=i
     endif
     !------------------------------------------
     
  enddo
  !---------------------------------------------------------------------------------------

  !---------------
  ! Making groups
  !------------------------------------------------------------------------------------------
  ! A group is formed by the pairs of all atoms of species i and of species j), necessary
  ! only if using PIV, not for SPRINT
  !------------------------------------------------------------------------------------------
  if( method .eq. 1 .or. method .eq. 2 )then

     !--------------------------
     ! Maximum size for a group
     !-----------------------------
     max_g=ns*(ns+1)/2
     max_gs=N_atoms*(N_atoms-1)/2
     !-----------------------------

     !----------------------------
     ! Allocating for group pairs
     !--------------------------------
     allocate(s2g(ns,ns))
     allocate(g2s(max_g,max_g))
     allocate(n2g(N_atoms,N_atoms,2))
     allocate(g2n(max_g,max_gs,2))
     allocate(gs(max_g))
     !--------------------------------

     !---------------------
     ! Initialize variables
     !------------------------------
     s2g=-1    ! ?
     ng=0      ! Number of groups
     !------------------------------

     !-------------------
     ! Computing groups
     !----------------------------------------------------------------------------
     do i=1,N_atoms-1

        !----------
        is=n2s(i)
        !----------

        !
        !------------------------------------------------------------------
        do j=i+1,N_atoms
           !---------------------------
           ! Initialize flag and dummy
           !---------------------------
           js=n2s(j)
           in=.false.
           !----------------------------
           
           !------------------------------------------------------------
           do ig=1,ng
              if( (s2g(is,js).eq.ig) .or. (s2g(js,is).eq.ig) ) then
                 in=.true.
                 gs(ig)=gs(ig)+1
                 n2g(i,j,1)=ig
                 n2g(i,j,2)=gs(ig)
                 g2n(ig,gs(ig),1)=i
                 g2n(ig,gs(ig),2)=j
              endif
           enddo
           !------------------------------------------------------------

           !------------------------
           if(.not.in) then
              ng=ng+1
              s2g(is,js)=ng
              s2g(js,is)=ng
              g2s(ng,1)=is
              g2s(ng,2)=js
              g2n(ng,1,1)=i
              g2n(ng,1,2)=j
              gs(ng)=1
           endif
           !-----------------------
           
        enddo
        !--------------------------------------------------------------------
        
     enddo
     !-----------------------------------------------------------------------------------
     
     !-------------------------------------------------------------------------------------------------------------------------
     ! From here we have gs(ig) (the group size) and g2n(ig,gs,2) which associates ig (group id) and gs (instance in group ig)
     ! - with the atom pair (2) i,j (where i,j are the index of the atom in the original xyz file)
     ! - Therefore we only need to loop overall groups and over the group size in each group to compute all-to-all distance matrix
     ! - and arrange it in vector of distance like vector=( (distances species1-species1)  (distances species1-species2) ... (distances species2-species3) ...  )
     ! - which is easy to sort over
     !--------------------------------------------------------------------------------------------------------------------------

     !-------------------------------------
     ! Vector size for the computing pairs
     !------------------------------------------------------------------------
     ! Number of Pairs
     vec_size=0   
     ! Loop over the number of groups?
     do ig=1,ng
        !------------------------------------------------
        ! For the main worker write the group information
        !-------------------------------------------------------------------------
        if(mpirank.eq.0) then
           print'(a6,i3,a3,a4,a3,a4,a6,i7,a12,$)'," group ",ig," (",trim(adjustl(s(g2s(ig,1))))," - ",adjustl(s(g2s(ig,2))),") has ",gs(ig)," atom pairs"
           print*
        endif
        !-------------------------------------------------------------------------

        !-------------------------------
        ! Add group size to total size
        !-------------------------------
        vec_size = vec_size + gs(ig)
        !-------------------------------
     enddo
     !------------------------------------------------------------------------
     
  endif
  !------------------------------------------------------------------------------------------

  !---------------
  ! Computing PIV
  !---------------------------------------------------------------------------------------------------------------------------
  if(.not.restart_piv) then

     !----------------------------------
     ! Writing in file for each worker
     !-----------------------------------
     write(svf_name,*),mpirank+1
     !-----------------------------------

     !-----------------------------------
     ! ??? Name of the file to write in
     !------------------------------------------------------------
     svf_name=trim(adjustl(svf_basename))//trim(adjustl(svf_name))
#ifdef STREAM
     open(unit=svu_write+mpirank,file=trim(adjustl(svf_name)),form='unformatted', access='stream')
#else
     if(mpirank.eq.0) then
        print'(a,i1,a)', 'Files written with direct access integer size: ', sizeofshortint, ' bytes'
     endif
     open(unit=svu_write+mpirank,file=trim(adjustl(svf_name)),form='unformatted', access='direct',recl=vec_size*sizeofshortint )
#endif
     !-----------------------------------------------------------------

     !----------------------------------------
     ! Sending information that computing PIV
     !-----------------------------------------------------
     if(mpirank.eq.0) then
        write(*,*) 
        write(*,*) "*** trajectory ***"
        write(*,*) 
        print '(a,$)', 'computing PIV for each frame...'
     endif
     !-----------------------------------------------------

     !----------------------------------------------
     ! Allocate for distance, position and v_matrix
     !-----------------------------------------------
     allocate(v_to_write(vec_size))  
     allocate(r(N_atoms,N_dim))
     allocate(dr(N_dim))
     !-----------------------------------------------
     
     !---------------------------------------------
     ! If SPRINT Allocation for vector of size N
     !---------------------------------------------
     if(method.eq.3)then
        allocate(contacts(N_atoms,N_atoms))
        allocate(v(N_atoms))
        allocate(vint(N_atoms))
        allocate(vtmp(N_atoms))
        allocate(vsorted(N_atoms))
        allocate(n2o(N_atoms))
     endif
     !----------------------------------------------

     !----------------------------------------------
     n_record=0        ! For parallel computation
     progress_bar=-1   ! Progress along calculation
     !----------------------------------------------

     !-----------------
     ! Loop Over Steps
     !----------------------------------------------------------------------------------------------------------------
     do n=1,n_steps

        !----------------------------------
        ! Computinng and printing progress
        !------------------------------------------------------------------------------------
        if((mpirank.eq.0).and.(n_steps.gt.20)) then
           if (mod(n,n_steps/20).eq.0) print '(i3,a,$)',nint(dble(100*n)/dble(n_steps)),"%"
        endif
        !------------------------------------------------------------------------------------

        !------------------------------
        ! Initialization of distances
        !------------------------------
        r(:,:)=atom_positions(n,:,:)
        !-------------------------------

        !---------------------------------------------
        ! Building H Matrix for PBC (non orthorombic)
        !------------------------------------------------------------------------------------------------------------
        if (pbc_type.eq.2) then

           !-------------------------------------
           cell(n,4:6)=dcos(cell(n,4:6)*deg2pi)
           cell(n,2:3)=cell(n,2:3)/cell(n,1)
           !-------------------------------------

           !-------------------------------------
           ! Testing compatiblity between angle
           !------------------------------------------------------------------------
           if (acos(cell(n,4))+acos(cell(n,5)).lt.acos(cell(n,6))) then
              write(*,*) 'error: alpha + beta < gamma'
              stop
           elseif (acos(cell(n,5))+acos(cell(n,6)).lt.acos(cell(n,4))) then
              write(*,*) 'error: beta + gamma < alpha'
              stop
           elseif (acos(cell(n,6))+acos(cell(n,4)).lt.acos(cell(n,5))) then
              write(*,*) 'error: gamma + alpha < beta'
              stop
           endif
           !------------------------------------------------------------------------
           
           !---------------------
           ! Computing H matrix
           !--------------------------------------------------------------------------------
           h(:,:)=0.d0
           tmpr=dsqrt(1.d0-cell(n,6)**2)
           h(1,1)=cell(n,1)
           h(2,1)=cell(n,1)*cell(n,2)*cell(n,6)
           h(2,2)=cell(n,1)*cell(n,2)*tmpr
           h(3,1)=cell(n,1)*cell(n,3)*cell(n,5)
           h(3,2)=cell(n,1)*cell(n,3)*(cell(n,4)-cell(n,5)*cell(n,6))/tmpr
           tmpr=(1.d0+2.d0*cell(n,4)*cell(n,5)*cell(n,6)-cell(n,4)**2-cell(n,5)**2-cell(n,6)**2)
           h(3,3)=cell(n,1)*cell(n,3)*dsqrt(tmpr/(1.d0-cell(n,6)**2))
           !----------------------------------------------------------------------------------

           !--------------------------------------------------------------------------
           ! note: here h contains vectors a b c as row vectors, not column vectors! 
           ! So we transpose to get back column vectors.
           !--------------------------------------------------------------------------
           h=transpose(h)
           !---------------

           !--------------
           ! Inverting H
           !-------------------------------------
           call invert(h,hi,ok_invert,volume)
           !-------------------------------------
           
           !---------------------------------------------
           ! Keeping the memory of volume0 for rescaling
           !------------------------------------------------------
           if ( n .eq. 1 .and. rescale ) then
              volume0 = volume
           endif
           !-------------------------------------------------------

           !------------------------------------------------------
           ! If there is a problem in the inversion of cell matrix
           !-------------------------------------------------------------------
           if (.not.ok_invert) then
              write(*,*) 'ERROR: impossible to invert h matrix (it is singular)'
              stop
           endif
           !--------------------------------------------------------------------

           !----------------
           ! Debug for cell
           !---------------------------------------------------------
           ! write(99,'(3f8.3,10x,3f8.3)') h(1,:),hi(1,:) ! debug
           ! write(99,'(3f8.3,10x,3f8.3)') h(2,:),hi(2,:) ! debug
           ! write(99,'(3f8.3,10x,3f8.3)') h(3,:),hi(3,:) ! debug
           !---------------------------------------------------------

        endif
        !--------------------------------------------------------------------------------------------------------

        !--------------------------------------------------
        ! Computing contact matrix, either PIV or SPRINT
        !----------------------------------------------------------------------------------------------------
        if( method .eq. 1 .or. method .eq. 2 ) then
           !---------------------------------------
           ! Compute PIV
           !--------------------------------------------------------------------------------------------------
           ! >>> use pairs (distances or coordination functions)
           !--------------------------------------------------------------------------------------------------
           if(mod(n-1,mpisize).eq.mpirank) then  ! ensuring that each proc computes the piv at a different step
              !----
              np=1
              !------
              
              !----------------------------
              ! Compute node number
              !-----------------------------
              n_record=n_record+1
              !-----------------------------

              ! Debug for MPI clock
              ! debug: call system_clock(tbeg0)

              !------------------------------------------------------------------------------------
              do ig=1,ng

                 gsi=gs(ig)

                 !-------------
                 ! Debug Clock
                 !---------------------------------
                 ! debug: call system_clock(tbeg)
                 !---------------------------------

                 !--------------------------------
                 ! Cleaning previous allocations
                 !-------------------------------------
                 if(allocated(v)) deallocate(v)
                 if(allocated(vint)) deallocate(vint)
                 if(allocated(n2o)) deallocate(n2o)
                 !-------------------------------------
                 
                 !---------------
                 ! Reallocating
                 !--------------------------------------
                 allocate(v(gsi))
                 allocate(vint(gsi))
                 allocate(n2o(gsi))
                 !--------------------------------------
                 
                 ! debug: call system_clock(tend)
                 ! debug: tall=tall+(tend-tbeg)

                 !!                ! heavy loops: here below I repeat a lot of code, it looks ugly but it is efficient
                 !!                !              because "if" inside a loop slows down a lot... NOT TRUE: with -O3 it is same speed!
                 !!                if( (pbc_type.eq.1) .and. (method.eq.2) .and. (coordtype.eq.1) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    dr=r(ii,:)-r(jj,:)
                 !!                    dr=dr-box_size*nint(dr/box_size)
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    d=1.d0/(1.d0+dexp(coord_lambda*(d-coord_d0)))
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif
                 !!                if( (pbc_type.eq.2) .and. (method.eq.2) .and. (coordtype.eq.1) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    do k=1,3 ! scaled coords
                 !!                      s1(k)=sum(hi(k,:)*r(ii,:))
                 !!                      s2(k)=sum(hi(k,:)*r(jj,:))
                 !!                    enddo
                 !!                    do k=1,3 ! minimum image convention
                 !!                      ds(k)=s1(k)-s2(k)
                 !!                      ds(k)=ds(k)-nint(ds(k))
                 !!                    enddo
                 !!                    do k=1,3 ! back to angstrom
                 !!                      dr(k)=sum(h(k,:)*ds(:))
                 !!                    enddo
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    d=1.d0/(1.d0+dexp(coord_lambda*(d-coord_d0)))
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif
                 !!                if( (pbc_type.eq.1) .and. (method.eq.2) .and. (coordtype.eq.2) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    dr=r(ii,:)-r(jj,:)
                 !!                    dr=dr-box_size*nint(dr/box_size)
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    tmpr=(d-coord_d0)/coord_r0
                 !!                    d=(1.d0-tmpr**coord_m)/(1.d0-tmpr**coord_n)
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif
                 !!                if( (pbc_type.eq.2) .and. (method.eq.2) .and. (coordtype.eq.2) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    do k=1,3 ! scaled coords
                 !!                      s1(k)=sum(hi(k,:)*r(ii,:))
                 !!                      s2(k)=sum(hi(k,:)*r(jj,:))
                 !!                    enddo
                 !!                    do k=1,3 ! minimum image convention
                 !!                      ds(k)=s1(k)-s2(k)
                 !!                      ds(k)=ds(k)-nint(ds(k))
                 !!                    enddo
                 !!                    do k=1,3 ! back to angstrom
                 !!                      dr(k)=sum(h(k,:)*ds(:))
                 !!                    enddo
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    tmpr=(d-coord_d0)/coord_r0
                 !!                    d=(1.d0-tmpr**coord_m)/(1.d0-tmpr**coord_n)
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif
                 !!                if( (pbc_type.eq.1) .and. (method.ne.2) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    dr=r(ii,:)-r(jj,:)
                 !!                    dr=dr-box_size*nint(dr/box_size)
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif
                 !!                if( (pbc_type.eq.2) .and. (method.ne.2) ) then
                 !!                  do i=1,gsi
                 !!                    ii=g2n(ig,i,1)
                 !!                    jj=g2n(ig,i,2)
                 !!                    do k=1,3 ! scaled coords
                 !!                      s1(k)=sum(hi(k,:)*r(ii,:))
                 !!                      s2(k)=sum(hi(k,:)*r(jj,:))
                 !!                    enddo
                 !!                    do k=1,3 ! minimum image convention
                 !!                      ds(k)=s1(k)-s2(k)
                 !!                      ds(k)=ds(k)-nint(ds(k))
                 !!                    enddo
                 !!                    do k=1,3 ! back to angstrom
                 !!                      dr(k)=sum(h(k,:)*ds(:))
                 !!                    enddo
                 !!                    d=dsqrt(dot_product(dr,dr))
                 !!                    v(i)=d
                 !!                    n2o(i)=i
                 !!                  enddo
                 !!                endif

                 ! --- heavy loop (note: putting IF commands outside does not help, at least with -O3)
                 do i=1,gsi

                    !--------
                    ! Group
                    !--------------
                    ii=g2n(ig,i,1)
                    jj=g2n(ig,i,2)
                    !---------------

                    !-------------
                    ! Debug clock
                    !---------------------------------
                    ! debug: call system_clock(tbeg)
                    !---------------------------------

                    !--------------------------------
                    ! Minimum image squared distance
                    !------------------------------------
                    if (pbc_type.eq.1) then
                       ! Orthorombic
                       dr=r(ii,:)-r(jj,:)
                       dr=dr-box_size*nint(dr/box_size)
                    else
                       ! Non Orthorombic
                       do k=1,3 ! scaled coords
                          s1(k)=sum(hi(k,:)*r(ii,:))
                          s2(k)=sum(hi(k,:)*r(jj,:))
                       enddo
                       do k=1,3 ! minimum image convention
                          ds(k)=s1(k)-s2(k)
                          ds(k)=ds(k)-nint(ds(k))
                       enddo
                       do k=1,3 ! back to angstrom
                          dr(k)=sum(h(k,:)*ds(:))
                       enddo
                    endif
                    !-----------------------------------

                    !-------------
                    ! Debug Clock
                    !---------------------------------
                    ! debug: call system_clock(tend)
                    ! debug: tpbc=tpbc+(tend-tbeg)
                    ! debug: call system_clock(tbeg)
                    !---------------------------------
                    
                    !----------
                    ! Distance
                    !----------------------------
                    d=dsqrt(dot_product(dr,dr))
                    !----------------------------

                    !-------------
                    ! Debug clock
                    !-----------------------------------
                    ! debug: call system_clock(tend)
                    ! debug: tsqr=tsqr+(tend-tbeg)
                    !-----------------------------------

                    !-------------------------------------------------------
                    ! Compute RDF from 0 to 10A with a resolution of 0.05A
                    ! -----------------------------------------------------
                    if (do_rdf) then !IF
                       if (d<10.d0) then !IF
                          rdf(1+int(d*20.d0))=rdf(1+int(d*20.d0))+1.d0
                       endif
                    endif
                    ! ---------------------------------------------------------

                    !--------------------------
                    ! Rescaling between phase
                    ! ------------------------------------
                    if ( rescale ) then
                       d = d*(volume0/volume)**0.33333333
                    endif
                    ! ------------------------------------

                    !------------
                    ! Debug Clock
                    !----------------------------------
                    ! debug: call system_clock(tbeg)
                    !----------------------------------

                    !------------------------------
                    ! Applying switching function
                    !-------------------------------------------------------
                    if(method.eq.2) then 
                       if(coordtype.eq.1) then 
                          d=1.d0/(1.d0+dexp(coord_lambda*(d-coord_d0)))
                       else  
                          tmpr=(d-coord_d0)/coord_r0
                          d=(1.d0-tmpr**coord_m)/(1.d0-tmpr**coord_n)
                       endif
                    endif
                    !--------------------------------------------------------

                    !-------------
                    ! Debug Clock
                    !---------------------------------
                    ! debug: call system_clock(tend)
                    ! debug: tcoo=tcoo+(tend-tbeg)
                    !---------------------------------

                    !----------------
                    ! Filling Matrix
                    !----------------
                    v(i)=d
                    n2o(i)=i
                    !----------------
                    
                 enddo
                 !--------------------------------------------------------------------------------------
                 ! End of heavy loop
                 !-------------------

                 do i=1,gsi
                    vint(i)=real2shortint(v(i),max_v,min_v)
                 enddo

                 ! debug: call system_clock(tbeg)

                 ! Sorting PIV
                 !------------------------------------------------------------------
                 if(sort) then !IF
                    ! debug: write(99,*) "sizeofshortint,size(vint),minval(vint),maxval(vint) =",sizeofshortint,size(vint),minval(vint),maxval(vint)
                    ! debug: write(100+n,'(i12)') vint
                    call counting_sort(size(vint),vint,minval(vint),maxval(vint))
                    ! debug: write(200+n,'(i12)') vint
                 endif
                 !------------------------------------------------------------------

                 ! Debug Clock
                 !---------------------------------
                 ! debug: call system_clock(tend)
                 ! debug: tsor=tsor+(tend-tbeg)
                 !---------------------------------

                 !--------------------------------------------------------------------
                 do i=1,gsi
                    v_to_write(np+i-1)=vint(i)
                 enddo
                 !                do i=1,gsi
                 !                  v_to_write(np+i-1)=real2shortint(v(i),max_v,min_v)
                 !                enddo
                 !--------------------------------------------------------------------

                 ! Number of group?
                 np=np+gsi

              enddo

              ! Debug clock
              !-----------------------------------
              ! debug: call system_clock(tend0)
              ! debug: ttot=ttot+(tend0-tbeg0)
              !----------------------------------

              
              ! Record for restart
              !---------------------------------------------
#ifdef STREAM
              do j=1,vec_size
                 write(svu_write+mpirank) v_to_write(j)
              enddo
#else
              write(svu_write+mpirank,rec=n_record) v_to_write
#endif
              !---------------------------------------------
           endif

        elseif(method.eq.3)then ! >>> use sprint
           ! SPRINT Method
           !---------------------------------------------------------------------------------------------------
           if(mod(n-1,mpisize).eq.mpirank) then  ! Worker
              
              !--------------------
              ! Number of worker
              !------------------------
              n_record = n_record+1
              !-----------------------

              !--------------------------
              ! Compute Contact Matrix
              !--------------------------------------------------------------
              contacts(:,:)=0.d0 ! All at 0
              ! Compute only the superior diagonal, faster
              !--------------------------------------------------------------
              do i=1,N_atoms-1
                 !------------------------------------------------------------
                 do j=i+1,N_atoms

                    ! Min Image Distance
                    !---------------------------------------
                    ! - Orthorombic PBC
                    !----------------------------------------
                    if (pbc_type.eq.1) then
                       dr=r(i,:)-r(j,:)
                       dr=dr-box_size*nint(dr/box_size)
                    else
                    !----------------------------------------
                    ! - Non orthorombic PBC
                    !----------------------------------------
                       do k=1,3 ! scaled coords
                          s1(k)=sum(hi(k,:)*r(i,:))
                          s2(k)=sum(hi(k,:)*r(j,:))
                       enddo
                       do k=1,3 ! minimum image convention
                          ds(k)=s1(k)-s2(k)
                          ds(k)=ds(k)-nint(ds(k))
                       enddo
                       do k=1,3 ! back to angstrom
                          dr(k)=sum(h(k,:)*ds(:))
                       enddo
                    endif
                    !---------------------------------------
                    
                    !----------------------------
                    ! Compute distance
                    !_---------------------------
                    d=dsqrt(dot_product(dr,dr))
                    !----------------------------

                    !------------------------------------
                    ! Compute RDF 0-10A, 0.05 Resolution
                    !----------------------------------------------------
                    if (do_rdf) then !IF
                       if (d<10.d0) then !IF
                          rdf(1+int(d*20.d0))=rdf(1+int(d*20.d0))+1.d0
                       endif
                    endif
                    !----------------------------------------------------

                    !------------------------------
                    ! Applying switching function
                    !--------------------------------------------------
                    if(coordtype.eq.1) then
                       d=1.d0/(1.d0+dexp(coord_lambda*(d-coord_d0)))
                    else  
                       tmpr=(d-coord_d0)/coord_r0
                       d=(1.d0-tmpr**coord_m)/(1.d0-tmpr**coord_n)
                    endif
                    !--------------------------------------------------

                    !---------------------
                    ! Fill Matrix
                    !---------------------
                    contacts(i,j)=d
                    contacts(j,i)=d
                    !---------------------
                   
                 enddo
                 !-----------------------------------------------------------------
              enddo
              !---------------------------------------------------------------------

              !-----------------
              ! Compute SPRINT
              !-------------------------------
              call sprint(N_atoms,contacts,v)
              !-------------------------------

              !-----------------------
              ! Sort SPRINT or not...
              !-------------------------------------------------------------
              if(sort)then
                 ! SORTING....
                 
                 !-------------------------------
                 ! Reordering species
                 !--------------------------------
                 i=0
                 do is=1,ns
                    do j=1,nat_spec(is)
                       i=i+1
                       vsorted(i)=v(s2n(is,j))
                    enddo
                 enddo
                 !--------------------------------

                 !--------------------------
                 ! Sort within each species
                 !------------------------------------------------------------------
                 do is=1,ns

                    if(is.eq.1) then
                       j = 1
                    else
                       j = sum(nat_spec(1:is-1))+1
                    endif

                    do i=1,nat_spec(is)
                       n2o(i) = i
                    enddo

                    vtmp(1:nat_spec(is))=vsorted(j:j+nat_spec(is)-1)
                    
                    ! note: here we call quicksort over real array,
                    ! if it gets too slow switch to counting_sort as above...
                    call dlasrt2('I',nat_spec(is),vtmp,n2o,lapack_err)
                    
                    !------------------------------------------------------------------
                    ! Check that the size is not above the maximum SPRINT allowed size
                    !------------------------------------------------------------------------------------
                    if( vtmp(nat_spec(is)) > max_sprint )then
                       write(*,*) "ERROR: sprint > max_sprint. Increase max_sprint and recompile. Exiting."
                       stop
                    endif
                    !------------------------------------------------------------------------------------

                    vsorted(j:j+nat_spec(is)-1)=vtmp(1:nat_spec(is))
                    
                 enddo
                 !------------------------------------------------------------------
                 
              else
                 
                 ! Do not Sort
                 !---------------
                 vsorted=v
                 !---------------
                 
              endif
              !-------------------------------------------------------------

              !--------------------
              ! Debug for SPRINT
              !----------------------------------------------------
              ! debug ! write(*,*) "SPRINT:"                     
              ! debug ! write(*,'(1000f8.3)') vsorted(1:N_atoms)
              !----------------------------------------------------

              !--------------------------------
              ! Write integer vectors to files
              !------------------------------------------------------
              do i=1,N_atoms
                 v_to_write(i)=real2shortint(vsorted(i),max_v,min_v)
              enddo
              !------------------------------------------------------
#ifdef STREAM
              ! - Writting V to restart
              !------------------------------------------------------
              do j=1,vec_size
                 write(svu_write+mpirank) v_to_write(j)
              enddo
              !------------------------------------------------------
#else
              !  - Writting V to restart
              !------------------------------------------------------
              write(svu_write+mpirank,rec=n_record) v_to_write
              !------------------------------------------------------
#endif              
           endif ! End of thread
           !-------------------------------------------------------------------------------------------------
        endif ! End of method
        !----------------------------------------------------------------------------------------------------
     enddo ! Loop Over Step
     !-------------------------------------------------------------------------------------------------------

     ! Closing Files and cleaning up memory
     !---------------------------------------
     close(svu_write+mpirank)
     if(allocated(v))deallocate(v)
     if(allocated(vint))deallocate(vint)
     if(allocated(vtmp))deallocate(vtmp)
     if(allocated(vsorted))deallocate(vsorted)
     if(allocated(n2o))deallocate(n2o)
     deallocate(r,dr,v_to_write)
     !---------------------------------------
     
  endif ! End of PIV computation
  !------------------------------------------------------------------------------------------------------------

  !-------------------
  ! Cleaning up memory
  !----------------------------------------------------
  deallocate(n2s,s,nat_spec,s2n)
  if(method.eq.1.or.method.eq.2.or.method.eq.4) then
     deallocate(s2g,g2s,n2g,g2n,gs)
  endif
  if(method.eq.3)then
     if(allocated(contacts))deallocate(contacts)
  endif
  !----------------------------------------------------

  !----------------------------------------
  ! Trying to compute frame to frame matrix
  !-------------------------------------------------------------------------------------------------------------
  if(.not.restart_matrix) then

     !--------------------------
     ! Tries to allocate matrix
     !-------------------------------------------------------------------------------------------------------------
     if(nint(sqrt(dble(ARRAY_SIZE))).lt.nint(dble(ARRAY_SIZE)/dble(vec_size)))then
        max_frames=nint(sqrt(dble(ARRAY_SIZE)))
     else
        max_frames=nint(dble(ARRAY_SIZE)/dble(vec_size))
     endif
     if(max_frames.gt.n_steps) max_frames=n_steps
#ifdef MPI
     call MPI_Barrier(MPI_COMM_WORLD, mpierror)
#endif
     !-------------------------------------------------------------------------------------------------------------
    
     !-------------------------
     ! Main Worker prints data
     !-----------------------------------------------------------------------------------------------------------------------
     if(mpirank.eq.0) then
        
        !--------------
        ! Debug Clock
        !----------------------------------------------------------------------------------------------
        ! debug: write(*,*) 
        ! debug: write(*,'(a,6i7)') '*** timing pbc,sqr,coo,all,sor =',tpbc,tsqr,tcoo,tall,tsor,ttot
        !----------------------------------------------------------------------------------------------

        !------------------------
        ! Number of frames read
        !----------------------------------------------------------------------------------------------------------------------
        print*,' DONE'   ! From here we have n_frames vectors of size vec_size which is sorted wihtin each group of distance
        print '(a,i8)', 'max_frames read at a time', max_frames
        !----------------------------------------------------------------------------------------------------------------------
        
     endif
     !-----------------------------------------------------------------------------------------------------------------------

     !----------------
     ! Computing RDF 
     !------------------------------------------------------------------------------------------------------------------
     if (do_rdf) then
        
        !-----------------------------------------------------------
        ! Computing MPI RDF or just use the previously computed one
        !----------------------------------------------------------------------------------------------------
#ifdef MPI
        call MPI_Reduce(rdf, rdf_global, 200, MPI_DOUBLE_PRECISION, MPI_SUM, 0, MPI_COMM_WORLD, mpierror);
#else
        rdf_global=rdf
#endif
        !----------------------------------------------------------------------------------------------------
        
        !-------------------------------------------
        ! Main Worker prints compute and prints RDF
        !--------------------------------------------------------------------------------------------------------------
        if (mpirank.eq.0) then

           !--------------
           ! Opening data
           !---------------------------------------------------------------------------
           write(*,*)
           write(*,*) "writing reduced distribution function to rdf.dat" ! Output file
           !-----------------------------------------------------------------------------
           
           !-------------------------------
           ! Opening file to write RDF in
           !-----------------------------------------
           open(345,file="rdf.dat",status="unknown")
           !-----------------------------------------

           !-------------------------------
           ! Compute Volume if orthorombic
           !-------------------------------------------------------------
           if (pbc_type.eq.1) volume=box_size(1)*box_size(2)*box_size(3)
           !-------------------------------------------------------------

           !-------------------
           ! Header of file
           !---------------------------------------------------------------------------
           write(345,*) '# r , g(r) , N(r).      volume=',volume           
           !---------------------------------------------------------------------------
           
           !-----------
           ! Init RDF
           !---------------------------------------------------------------------
           rdf_global=rdf_global*2.d0/dble(n_atoms*n_steps)                ! Compute rdf
           rdf_n=0.d0
           !---------------------------------------------------------------------

           !--------------------------------
           ! Compute and write RDF to file
           !----------------------------------------------------------------------------------------------------
           do i=1,200
              d=dble(i-1)*0.05
              tmpr=(4.d0*3.14159265d0/3.d0) * ((d+0.05)**3-d**3)
              rdf_n=rdf_n+rdf_global(i)
              write(345,'(f8.3,2f16.3)') d,rdf_global(i)/(tmpr*dble(n_atoms)/volume),rdf_n  ! Write RDF to file
              ! note: here volume is that of the last frame, it can be a bad approximation if cell is not stable...
           enddo
           !----------------------------------------------------------------------------------------------------

           !-------------------------------
           ! Closing File and exit message
           !--------------------------------
           close(345)
           write(*,*) "DONE"
           !----------------------------------
           
        endif
        !-----------------------------------------------------------------------------------------------------------------
     endif
     !-----------------------------------------------------------------------------------------------------------------

     !---------------------------------------------
     ! Compute the size of the frame 2 frame matrix
     !---------------------------------------------
     nn=n_steps*(n_steps-1)/2
     !---------------------------------------------

     !-------------------------------------
     ! Allocate vectors to store distances
     !---------------------------------------------
     allocate(v1(vec_size),v2(vec_size))
     allocate(reduced_piv1(max_frames,vec_size))
     allocate(reduced_piv2(max_frames,vec_size))
     allocate(frame2frame(n_steps,n_steps))
     !---------------------------------------------
     !this way of doing is not appropriate for more than ~25'000 steps
     !a fix is to write on disk as before or scatter and gather the matrices
     !the way is implemented now has to change !
     !-----------------------------------------------

     ! 
     !---------------------
     frame2frame=0.d0
     v1=0.d0
     v2=0.d0
     l=10
     cutoff2=cutoff**2
     progress_bar=0
     !---------------------

     !---------------
     ! User message
     !---------------------------------------------------------
     if(mpirank.eq.0) then
        print*, ''
        print*, '*** frame-to-frame distance matrix ***'
        print*, ''
     endif
     !---------------------------------------------------------

     !-----------------------------------------------------------------------
     ! Compute progress max value to get an idea of the amount of work to do
     !------------------------------------------------------------------------
     progress_tot=0
     do m=1,n_steps-1,max_frames
        do n=m+1,n_steps,max_frames
           progress_tot=progress_tot+1
        enddo
     enddo
     !--------------------------------------------------------------------------

     !---------------------------------------
     ! Loops going over every pair of frames
     !--------------------------------------------------------------------------------------------------------------------
     do m=1,n_steps-1,max_frames
        do n=m+1,n_steps,max_frames
           
           !--------------------------
           ! Main Worker reads block and prints informations
           !--------------------------------------------------------------------------------------------------------
           if(mpirank.eq.0) then
              print'(a,i5,a,i5,a,$)','  Reading block (',m,';',n,')'
              call read_blocks(mpisize,svf_basename,m,n_steps,reduced_piv1,max_frames,vec_size,max_v,min_v)
              call read_blocks(mpisize,svf_basename,n,n_steps,reduced_piv2,max_frames,vec_size,max_v,min_v)
              print'(a,$)',' DONE'
              print'(a,$)','  Broadcasting...'
           endif
           !---------------------------------------------------------------------------------------------------------

           !------------------
           ! Broadcast matrix
           !------------------------------------------------------------------------------------------
#ifdef MPI            
#ifdef FOURBYTES
           call MPI_Bcast(reduced_piv1,max_frames*vec_size,MPI_integer,0,MPI_COMM_WORLD,mpierror)
           call MPI_Bcast(reduced_piv2,max_frames*vec_size,MPI_integer,0,MPI_COMM_WORLD,mpierror)
#else
           call MPI_Bcast(reduced_piv1,max_frames*vec_size,MPI_integer2,0,MPI_COMM_WORLD,mpierror)
           call MPI_Bcast(reduced_piv2,max_frames*vec_size,MPI_integer2,0,MPI_COMM_WORLD,mpierror)
#endif  
#endif
           !------------------------------------------------------------------------------------------

           !---------------
           ! User message
           !-------------------------------------------------------------
           if(mpirank.eq.0) then
              print'(a,$)',' DONE'
              print'(a,$)','  Computing...'
           endif
           !-------------------------------------------------------------

           !-------
           ! Index
           !--------
           mm=0
           !----------

           ! Loop Over frames
           !-------------------------------------------------------------------------------------------------------------------
           do i=1,max_frames

              !-------
              ! Index
              !------------------
              real_stepi=m+i-1
              !-------------------

              !------------------
              ! Loop over steps
              !------------------------------------------------------------------------------------------------
              if( m+i-1 .le. n_steps-1 ) then

                 !-------------------
                 ! Loop over frames
                 !-----------------------------------------------------------------------------------------------
                 do j=1,max_frames
                    
                    !------
                    ! Index
                    !-----------------
                    real_stepj=n+j-1
                    !-----------------
                    
                    ! -------------------------------------------------------------------------------------------------------------
                    if(n+j-1.le.n_steps .and. real_stepj.gt.real_stepi) then
                       
                       ! Index 
                       mm=mm+1
                       
                       ! Parallelization in order to go faster
                       !_---------------------------------------------------------------------------------------------------------
                       if(mod(mm,mpisize).eq.mpirank) then  ! easy way of ensuring that each proc computes a different m,n dmsd

                          !------------------------
                          ! Computes PIV distance
                          !--------------------------------------------------------
                          do k=1,vec_size
                             v1(k)=shortint2real(reduced_piv1(i,k),max_v,min_v)
                             v2(k)=shortint2real(reduced_piv2(j,k),max_v,min_v)
                          enddo
                          !--------------------------------------------------------
                          
                          !-----------------------------------
                          ! Computes distance between frames
                          !------------------------------------------------------
                          dmsd=sum((v1(1:vec_size)-v2(1:vec_size))**2)
                          dmsd=dsqrt(dmsd)
                          !-------------------------------------------------------

                          !------------------------------------------
                          ! Filling up the matrix
                          !-------------------------------------------
                          frame2frame(real_stepi,real_stepj)=dmsd     ! - in which case frame2frame(m,n) takes the value of the dmsd; if they are not
                          frame2frame(real_stepj,real_stepi)=dmsd     ! - frame2frame frame2frame(m,n) remains at 0.d0 (inital value)
                          !-------------------------------------------
                          
                       endif
                       !---------------------------------------------------------------------------------------------------------
                    endif
                    !--------------------------------------------------------------------------------------------------------------
                 enddo
                 !--------------------------------------------------------------------------------------------------
              endif
              !------------------------------------------------------------------------------------------------
           enddo
           !-------------------------------------------------------------------------------------------------------------------

           ! Broadcast
           !------------------------------------------------
#ifdef MPI
           call MPI_Barrier(MPI_COMM_WORLD, mpierror)
#endif
           !------------------------------------------------

           !------------------------
           ! Updating progress bar
           !-----------------------------
           progress_bar=progress_bar+1
           !-----------------------------

           !-------------------
           ! Printing progress
           !------------------------------------------------------------------------
           if(mpirank.eq.0) then
              print'(a,f5.1,a)', ' DONE ',100.*progress_bar/dble(progress_tot),'%'
           endif
           !------------------------------------------------------------------------
           
        enddo
        !---------------------------------------------------------------------------------------------------------------------------
     enddo
     !---------------------------------------------------------------------------------------------------------------------------

     !--------------------------
     ! Cleaning unused vectors
     !----------------------------
     deallocate(v1,v2)
     !----------------------------

     !----------
     ! Barrier?
     !---------------------------------------
#ifdef MPI
     call MPI_Barrier(MPI_COMM_WORLD, mpierror)
#endif
     !---------------------------------------

     !-------------
     ! Message out
     !---------------------------------------
     if(mpirank.eq.0) then
        print '(a,$)','collecting the data from each proc...'
     endif
     !---------------------------------------

     !--------------------------
     ! Collecting matrix element 
     !---------------------------------------
     allocate(frame2frame_save(n_steps,n_steps))
     ! If MPI....
#ifdef MPI
     call MPI_Allreduce(frame2frame,frame2frame_save,n_steps*n_steps,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD, mpierror) ! Since every proc has either 0.d0 or the dmsd value
     frame2frame=frame2frame_save                                                                                           ! - the sum of all the matrices on each proc will give the corrct matrix
#else
     ! If Serial
     frame2frame_save=frame2frame
#endif
     !--------------------------------------------
     
     !------------------
     ! Cleaning memory
     !--------------------------------------
     deallocate(frame2frame_save)
     !---------------------------------------
     
  endif ! End of computation of matrix
  !-------------------------------------------------------------------------------------------------------------------------------------------------------

  !-------------------------------------
  ! Other than Main Worker cleans memory
  !--------------------------------------
  if(mpirank.ne.0) then
     
     !--------------------
     ! Cleaning matrix
     !--------------------------------
     if( .not. restart_matrix ) then 
        deallocate(frame2frame)
     endif
     !---------------------------------

     !-----------------
     ! Cleaning memory
     !------------------------------
     deallocate(n2t,atom_positions)
     !------------------------------
     
  else
     ! Main Worker
     !--------------
     ! From that point there we only carry the operations on 1 proc the endif is at the end of the program

     !--------------
     ! Printint out
     !-----------------
     print*, ' DONE'
     !-----------------

     !----------------------------------------------------
     ! if not restarting from previously computed matrix
     !------------------------------------------------------------------------------------------
     if(.not.restart_matrix) then

        !-------------
        ! Out message
        !-------------------------------------------------------
        print '(a,$)', 'writing to disk FRAME_TO_FRAME.MATRIX...'
        !_--------------------------------------------------------

        ! Opening outfile
        !-------------------------------------------------
        open(unit=write204, file = "FRAME_TO_FRAME.MATRIX")
        !-----------------------------------------------------

        !-------------------------------------------
        ! Computing max distance from frame to frame
        !_----------------------------------------------
        distmax=maxval(frame2frame)
        !_----------------------------------------------

        !-------------------------------
        ! Writting max distance to file
        !_----------------------------------------------
        write(write204,'(i12,f20.10)') n_steps,distmax
        !-----------------------------------------------

        !-------------------------------------------------------------------
        ! Writting frame to frame distances, normalized by max distances
        !-------------------------------------------------------------------
        ! Loop over steps
        do i=1,n_steps
           ! Loop over steps
           do j=1,n_steps
              ! Writting
              write(write204,'(f8.5,$)'),frame2frame(i,j)/distmax
           enddo
           ! Endline
           write(write204,*),""
        enddo
        !_------------------------------------------------------------------

        !---------------
        ! Closing file
        !----------------
        close(write204)
        !----------------

        !---------------
        ! Printing done
        !----------------
        print*, ' DONE'
        !----------------
        
        !-----------------------------------------------------------------------------------------
     else

        print '(a,$)', 'reading from disk FRAME_TO_FRAME.MATRIX...'

        allocate(frame2frame(n_steps,n_steps))

        open(unit=read104, file = "FRAME_TO_FRAME.MATRIX")

        read(read104,*) readnsteps,distmax

        if(readnsteps.ne.n_steps)then
           write(*,*) 'ERROR: mismatch between n_steps in FRAME_TO_FRAME.MATRIX and from trajectory. Exiting.'
           stop
           
        endif
        
        do i=1,n_steps
           read(read104,*) (frame2frame(i,j),j=1,n_steps)
        enddo
        
        close(read104)
        
        frame2frame=frame2frame*distmax
        
        print*, ' DONE'
        
     endif
     !-------------------------------------------------------------------------------------------
     
     !----------------------------------------
     ! Printing information about structures
     !-----------------------------------------------------------------------------------------------
     dista=sum(frame2frame(:,:))/dble(n_steps**2)
     dista2=sum(frame2frame(:,:)**2)/dble(n_steps**2)
     dista2=dsqrt(dista2-dista*dista)
     write(*,'(a,3f12.6)') ' aver, rmsd, max dist. between frames =',dista,dista2,distmax
     !-------------------------------------------------------------------------------------------------
     
     !--------------
     ! Clustering
     !-----------------------------------------------------------------------------------------------------------------
     ! Start message
     !--------------------------------
     write(*,*) 
     write(*,*) "*** clustering ***"
     write(*,*)
     !---------------------------------
     ! Clustering in itself
     !---------------------------------------------------------------------------------------------------------------
     select case (algorithm)
        ! Daura
     case (1)
        call daura_algorithm(frame2frame,n_steps,n_clusters,cluster_size,cluster_centers,cluster_members,cutoff)
        ! Kmenoid
     case (2)
        call kmedoids_algorithm(frame2frame,n_steps,n_clusters,cluster_size,cluster_centers,cluster_members)
     end select
     !-----------------------------------------------------------------------------------------------------------------
     
     !-------------------------------------
     ! Computing clustering coefficients
     !------------------------------------------------------------------------------------------------------------------------------------------------
     if (cutoff_clcoeff>0.d0) then

        !--------------------
        ! Allocating memory
        !---------------------------------------------
        allocate(clustering_coefficients(n_clusters))
        !---------------------------------------------

        !-----------------------------
        ! compute clustering coeff
        !--------------------------------------------------------------------------------------------------------------------------------------------
        call compute_clustering_coefficients(frame2frame,n_steps, n_clusters,cluster_members,cluster_size, clustering_coefficients,cutoff_clcoeff)
        !--------------------------------------------------------------------------------------------------------------------------------------------

        !----------------------------------
        ! Writting clustering coefficients
        !-----------------------------------------------------
        write(*,*) " clustering coefficients:"
        do i=1,n_clusters
           write(*,'(i4,f14.6)') i,clustering_coefficients(i)
        enddo
        !------------------------------------------------------

        !-------------------
        ! Jumping lines
        !------------------
        write(*,*)
        !-------------------

        !-----------------
        ! Cleaning memory
        !----------------------------------
        deallocate(clustering_coefficients)
        !----------------------------------
        
     endif
     !------------------------------------------------------------------------------------------------------------------------------------------------

     !--------------------------
     ! temporary name for files
     !------------------------
     tmp_char=out_file ! file name
     !--------------------------
     
     !--------------------------------------------------------------
     ! Printing information about number of cluster and largest size
     !------------------------------------------------------------------------------------------------------------------------------ 
     print '(a,i8,a,i5)','we have identified ',n_clusters,' clusters, the biggest is of size ', cluster_size(1)
     print '(a,$)','printing cluster structures to files...'
     !-------------------------------------------------------------------------------------------------------------------------------


     !?
     !_---------
     tot_acs=0
     !----------

     !--------------------------
     ! Opens clusters centers 
     !--------------------------------------
     open(unit=write202,file='centers.xyz')
     !---------------------------------------

     !----------------------
     ! Loop over clusters
     !---------------------------------------------------------------------------------------------------------------------
     do k=1,n_clusters ! 

        !-------------------
        ! Writes cluster k
        !------------------------
        write(out_file,*) k
        !-------------------------

        !------------------------------------------
        !  Get the name of the file for cluster k
        !-----------------------------------------------------------
        out_file=trim(tmp_char)//trim(adjustl(out_file))//'.xyz'
        open(unit=write201,file=trim(adjustl(out_file)))
        !------------------------------------------------------------

        ! ?
        !-------------------------
        kk=0
        ii=cluster_centers(k)
        acs=cluster_size(k) !because actual_cluster_size was sorted
        tot_acs=tot_acs+acs
        !-------------------------

        !--------------------------------------
        ! Writes the center to file centers.xyz
        !----------------------------------------------------------------------------------------------------------------------------
        write(write202,'(i8)') n_atoms
        write(write202,'(a,i4,a,i6,$)') 'cluster',k,' size',acs
        write(write202,'(a,f7.2,a,f7.2,a,$)') ' pop',dble(acs)/dble(n_steps)*100,'% tot_pop', dble(tot_acs)/dble(n_steps)*100,'%'
        write(write202,'(a,i6,2x,a)') ' frame',ii,trim(adjustl(comments(ii)))
        do iat=1,n_atoms
           write(write202,'(a4,3f8.3)'),n2t(iat),(atom_positions(ii,iat,l),l=1,n_dim)
        enddo
        !-----------------------------------------------------------------------------------------------------------------------------

        !--------------------------------------------
        ! writes all members to file cluster*.xyz
        !--------------------------------------------------------------------------------------------------------------------
        do j=1,acs

           !---------------------------
           ! gets the cluster members
           !-----------------------------
           jj=cluster_members(k,j)
           !-----------------------------

           !-----------
           ! Writes all
           !------------------------------------------------------------------------------------------------------------------------------
           write(write201,'(i8)') n_atoms ! number of atomes
           write(write201,'(a,i6,a,f8.3,a,i6,2x,a)') 'member',j,' dist',frame2frame(jj,ii),' frame',jj,trim(adjustl(comments(jj))) ! member, distance, frame
           do iat=1,n_atoms
              write(write201,'(a4,3f8.3)'),n2t(iat),(atom_positions(jj,iat,l),l=1,n_dim) ! atomic positions?
           enddo
           !-------------------------------------------------------------------------------------------------------------------------------
           
        enddo
        !-----------------------------------------------------------------------------------------------------------------------

        !-------------
        ! Closing file
        !------------------
        close(write201)
        !------------------
     enddo
     !---------------------------------------------------------------------------------------------------------------------------------

     !--------------
     ! Closing file
     !---------------
     close(write202)
     
     !---------------
     ! Done Message
     !---------------
     print '(a)',' DONE'
     !------------------------------------------------------------------------------------------------------------------------------
     
     !--------------------------
     ! Prints cluster network
     !----------------------------------------------------------------------
     if (network_analysis) then
        
        !--------------------------
        ! Allocating cluster link
        !---------------------------------------------
        allocate(cluster_link(n_clusters,n_clusters))
        !---------------------------------------------

        !--------------
        ! Cluster link
        !---------------
        cluster_link=0
        !---------------

        !--------------
        ! Opening file
        !------------------------------
        open(unit=789,file="network")
        !------------------------------

        !---------------------
        ! Loop over clusters
        !---------------------------------------------------------------------------
        do i=1,n_clusters-1
           do j=i+1,n_clusters
              
              ! Get the distance between two frames
              !-----------------------------------------------------------
              dist_ij=frame2frame(cluster_centers(i),cluster_centers(j))
              !-----------------------------------------------------------

              !------------------------
              ! Flag to see if linked
              !------------------------
              linked=.true.
              !------------------------

              ! Loop over clusters
              !---------------------------------------------------------------
              do k=1,n_clusters

                 !----------------------
                 ! Avoids i==k or j==k
                 !--------------------------------
                 if ((i.eq.k).or.(j.eq.k)) cycle
                 !--------------------------------

                 !--------------------------------------------------
                 ! Computes distances between i and k and j and k
                 !------------------------------------------------------------
                 dist_ik=frame2frame(cluster_centers(i),cluster_centers(k))
                 dist_jk=frame2frame(cluster_centers(j),cluster_centers(k))
                 !------------------------------------------------------------
                 
                 !----------------------------------------------------------------
                 ! Determine if i and j are linked, i.e the closest to each other
                 !----------------------------------------------------------------
                 if (dist_ij**2.gt.dist_ik**2+dist_jk**2) linked=.false.
                 !-----------------------------------------------------------------

              enddo
              !---------------------------------------------------------------

              !-----------------------
              ! If linked write data
              !-------------------------------------------
              if (linked) then

                 !----------------------
                 ! Update cluster matrix
                 !---------------------
                 cluster_link(i,j)=1
                 cluster_link(j,i)=1
                 !---------------------

                 !---------------
                 ! Printing info
                 !-------------------------------------
                 write(789,'(2i6,f12.6)') i,j,dist_ij
                 !-------------------------------------
                 
              endif
              !-------------------------------------------
              
           enddo
        enddo
        !---------------------------------------------------------------------------
        
        !------------
        ! Close file
        !-------------
        close(789)
        !--------------

        !---------------
        ! Printing info
        !------------------------------------------------------
        write(*,*) 'written links (i j dist) in file "network"'
        !-------------------------------------------------------

        !-------------------
        ! Printing network
        !--------------------------------------------
        call print_network(n_clusters,cluster_link)
        !--------------------------------------------

        !-----------------------------
        ! Deallocation cluster links
        !------------------------------
        deallocate(cluster_link)
        !------------------------------
        
     endif
     !----------------------------------------------------------------------------

     !------------------
     ! Cleaning memory
     !---------------------------------------------------------------------------------------
     deallocate(cluster_centers,cluster_members,cluster_size,atom_positions,n2t,frame2frame)
     !---------------------------------------------------------------------------------------

     !--------------
     ! Exit message
     !---------------------------------------
     write(*,*) 
     write(*,*) '*** end of program ***'
     !---------------------------------------
     
  endif ! End for main worker
  !-------------------------------------------------------------------------------------------------------------------------------------
  
  !------------
  ! Close MPI
  !-------------------------------------
#ifdef MPI
  call MPI_Finalize(mpierror)
#endif
  !-------------------------------------
  
end program clustering_dmsd
