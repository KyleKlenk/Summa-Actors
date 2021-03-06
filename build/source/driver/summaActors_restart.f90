! SUMMA - Structure for Unifying Multiple Modeling Alternatives
! Copyright (C) 2014-2020 NCAR/RAL; University of Saskatchewan; University of Washington
!
! This file is part of SUMMA
!
! For more information see: http://www.ral.ucar.edu/projects/summa
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

module summa4chm_restart
! read restart data and reset the model state


USE data_types,only:&
                    ! no spatial dimension
                    var_i,               & ! x%var(:)            (i4b)
                    var_i8,              & ! x%var(:)            (i8b)
                    var_d,               & ! x%var(:)            (dp)
                    var_ilength,         & ! x%var(:)%dat        (i4b)
                    var_dlength            ! x%var(:)%dat        (dp)

! access missing values
USE globalData,only:integerMissing   ! missing integer
USE globalData,only:realMissing      ! missing double precision number

! named variables
USE var_lookup,only:iLookPROG                               ! look-up values for local column model prognostic (state) variables
USE var_lookup,only:iLookDIAG                               ! look-up values for local column model diagnostic variables
USE var_lookup,only:iLookFLUX                               ! look-up values for local column model fluxes
USE var_lookup,only:iLookBVAR                               ! look-up values for basin-average model variables
USE var_lookup,only:iLookDECISIONS                          ! look-up values for model decisions

! safety: set private unless specified otherwise
implicit none
private
public::summa4chm_readRestart
contains

 ! read restart data and reset the model state
 subroutine summa4chm_readRestart(&
                indxGRU,    & ! index of GRU in gru_struc
                indxHRU,    & ! index of HRU in gru_struc
                ! primary data structures (variable length vectors)
                indxStruct, & ! x%var(:)%dat -- model indices
                mparStruct, & ! x%var(:)%dat -- model parameters
                progStruct, & ! x%var(:)%dat -- model prognostic (state) variables
                diagStruct, & ! x%var(:)%dat -- model diagnostic variables
                fluxStruct, & ! x%var(:)%dat -- model fluxes
                ! basin-average structures
                bvarStruct, & ! x%var(:)%dat        -- basin-average variables
                dt_init,    & ! used to initialize the length of the sub-step for each HRU
                err, message)
 ! ---------------------------------------------------------------------------------------
 ! * desired modules
 ! ---------------------------------------------------------------------------------------
 ! data types
 USE nrtype                                                  ! variable types, etc.
 ! functions and subroutines
 USE time_utils_module,only:elapsedSec                       ! calculate the elapsed time
 USE read_icond4chm_module,only:read_icond4chm               ! module to read initial conditions
 USE check_icond4chm_module,only:check_icond4chm             ! module to check initial conditions
 USE var_derive_module,only:calcHeight                       ! module to calculate height at layer interfaces and layer mid-point
 USE var_derive_module,only:v_shortcut                       ! module to calculate "short-cut" variables
 USE var_derive_module,only:rootDensty                       ! module to calculate the vertical distribution of roots
 USE var_derive_module,only:satHydCond                       ! module to calculate the saturated hydraulic conductivity in each soil layer
 ! global data structures
 USE globalData,only:model_decisions                         ! model decision structure
 ! file paths
 USE summaActors_FileManager,only:SETTINGS_PATH                     ! path to settings files (e.g., Noah vegetation tables)
 USE summaActors_FileManager,only:STATE_PATH                        ! optional path to state/init. condition files (defaults to SETTINGS_PATH)
 USE summaActors_FileManager,only:MODEL_INITCOND                    ! name of model initial conditions file
 ! timing variables
 USE globalData,only:startRestart,endRestart                 ! date/time for the start and end of reading model restart files
 USE globalData,only:elapsedRestart                          ! elapsed time to read model restart files
 ! model decisions
 USE mDecisions_module,only:&                                ! look-up values for the choice of method for the spatial representation of groundwater
  localColumn, & ! separate groundwater representation in each local soil column
  singleBasin    ! single groundwater store over the entire basin
 ! ---------------------------------------------------------------------------------------
 ! * variables
 ! ---------------------------------------------------------------------------------------
 implicit none
 ! dummy variables
 integer(i4b),intent(in)                  :: indxGRU            !  index of GRU in gru_struc
 integer(i4b),intent(in)                  :: indxHRU            !  index of HRU in gru_struc
 ! primary data structures (variable length vectors)
 type(var_ilength),intent(inout)          :: indxStruct         !  model indices
 type(var_dlength),intent(inout)          :: mparStruct         !  model parameters
 type(var_dlength),intent(inout)          :: progStruct         !  model prognostic (state) variables
 type(var_dlength),intent(inout)          :: diagStruct         !  model diagnostic variables
 type(var_dlength),intent(inout)          :: fluxStruct         !  model fluxes
 ! define the basin-average structures
 type(var_dlength),intent(inout)          :: bvarStruct         !  basin-average variables
 real(dp),intent(inout)                   :: dt_init
 integer(i4b),intent(out)                 :: err                ! error code
 character(*),intent(out)                 :: message            ! error message
 ! local variables
 character(LEN=256)                       :: cmessage           ! error message of downwind routine
 character(LEN=256)                       :: restartFile        ! restart file name
 integer(i4b)                             :: nGRU               
 ! ---------------------------------------------------------------------------------------
 ! initialize error control
 err=0; message='summa4chm_readRestart/'
 nGRU = 1

 ! identify the start of the writing
 call date_and_time(values=startRestart)

 ! *****************************************************************************
 ! *** read/check initial conditions
 ! *****************************************************************************

 ! define restart file path/name
 if(STATE_PATH == '') then
   restartFile = trim(SETTINGS_PATH)//trim(MODEL_INITCOND)
 else
   restartFile = trim(STATE_PATH)//trim(MODEL_INITCOND)
 endif

 ! read initial conditions
 call read_icond4chm(&
                 indxGRU,                       & ! intent(in):    index of GRU in gru_struc
                 indxHRU,                       & ! intent(in):    index of HRU in gru_struc
                 restartFile,                   & ! intent(in):    name of initial conditions file
                 mparStruct,                    & ! intent(in):    model parameters
                 progStruct,                    & ! intent(inout): model prognostic variables
                 bvarStruct,                    & ! intent(inout): model basin (GRU) variables
                 indxStruct,                    & ! intent(inout): model indices
                 err,cmessage)                    ! intent(out):   error control
 if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

 ! check initial conditions
 call check_icond4chm(&
                  indxGRU,                        & ! intent(in):   index of GRU in gru_struc
                  indxHRU,                        & ! intent(in):   index of HRU in gru_struc           
                  progStruct,                     & ! intent(in):   model prognostic (state) variables
                  mparStruct,                     & ! intent(in):   model parameters
                  indxStruct,                     & ! intent(in):   layer indexes
                  err,cmessage)                   ! intent(out):   error control
 if(err/=0)then; message=trim(message)//trim(cmessage); return; endif


  ! *****************************************************************************
  ! *** compute ancillary variables
  ! *****************************************************************************

  ! re-calculate height of each layer
  call calcHeight(indxStruct,   & ! layer type
                  progStruct,   & ! model prognostic (state) variables for a local HRU
                  err,cmessage)                       ! error control
  if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

  ! calculate vertical distribution of root density
  call rootDensty(mparStruct,   & ! vector of model parameters
                  indxStruct,   & ! data structure of model indices
                  progStruct,   & ! data structure of model prognostic (state) variables
                  diagStruct,   & ! data structure of model diagnostic variables
                  err,cmessage)                       ! error control
  if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

  ! calculate saturated hydraulic conductivity in each soil layer
  call satHydCond(mparStruct,   & ! vector of model parameters
                  indxStruct,   & ! data structure of model indices
                  progStruct,   & ! data structure of model prognostic (state) variables
                  fluxStruct,   & ! data structure of model fluxes
                  err,cmessage)                       ! error control
  if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

  ! calculate "short-cut" variables such as volumetric heat capacity
  call v_shortcut(mparStruct,   & ! vector of model parameters
                  diagStruct,   & ! data structure of model diagnostic variables
                  err,cmessage)                       ! error control
  if(err/=0)then; message=trim(message)//trim(cmessage); return; endif

  ! initialize canopy drip
  ! NOTE: canopy drip from the previous time step is used to compute throughfall for the current time step
  fluxStruct%var(iLookFLUX%scalarCanopyLiqDrainage)%dat(1) = 0._dp  ! not used

  ! *****************************************************************************
  ! *** initialize aquifer storage
  ! *****************************************************************************

  ! initialize aquifer storage
  ! NOTE: this is ugly: need to add capabilities to initialize basin-wide state variables

  ! There are two options for groundwater:
  !  (1) where groundwater is included in the local column (i.e., the HRUs); and
  !  (2) where groundwater is included for the single basin (i.e., the GRUS, where multiple HRUS drain into a GRU).

  ! For water balance calculations it is important to ensure that the local aquifer storage is zero if groundwater is treated as a basin-average state variable (singleBasin);
  !  and ensure that basin-average aquifer storage is zero when groundwater is included in the local columns (localColumn).

  ! select groundwater option
  select case(model_decisions(iLookDECISIONS%spatial_gw)%iDecision)

   ! the basin-average aquifer storage is not used if the groundwater is included in the local column
   case(localColumn)
    bvarStruct%var(iLookBVAR%basin__AquiferStorage)%dat(1) = 0._dp ! set to zero to be clear that there is no basin-average aquifer storage in this configuration

   ! the local column aquifer storage is not used if the groundwater is basin-average
   ! (i.e., where multiple HRUs drain to a basin-average aquifer)
   case(singleBasin)
    bvarStruct%var(iLookBVAR%basin__AquiferStorage)%dat(1) = 1._dp
    progStruct%var(iLookPROG%scalarAquiferStorage)%dat(1) = 0._dp  ! set to zero to be clear that there is no local aquifer storage in this configuration

   ! error check
   case default
    message=trim(message)//'unable to identify decision for regional representation of groundwater'
    return

  end select  ! groundwater option

  ! *****************************************************************************
  ! *** initialize time step
  ! *****************************************************************************

  ! initialize time step length
   dt_init = progStruct%var(iLookPROG%dt_init)%dat(1) ! seconds
   

 ! *****************************************************************************
 ! *** finalize
 ! *****************************************************************************

 ! identify the end of the writing
 call date_and_time(values=endRestart)

 ! aggregate the elapsed time for model writing
 elapsedRestart = elapsedSec(startRestart, endRestart)

 end subroutine summa4chm_readRestart
end module summa4chm_restart




