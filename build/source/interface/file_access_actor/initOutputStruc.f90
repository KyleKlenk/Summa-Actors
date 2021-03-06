module summaActors_initOutputStruct
  USE nrtype
  implicit none
  public::initalizeOutput
  contains

subroutine initalizeOutput(forcFileInfo, maxSteps, nGRU, err)
  USE globalData,only:outputStructure
  USE globalData,only:outputStructure
  USE globalData,only:time_meta,forc_meta,attr_meta,type_meta ! metadata structures
  USE globalData,only:prog_meta,diag_meta,flux_meta,id_meta   ! metadata structures
  USE globalData,only:mpar_meta,indx_meta                     ! metadata structures
  USE globalData,only:bpar_meta,bvar_meta                     ! metadata structures
  USE globalData,only:statForc_meta                           ! child metadata for stats
  USE globalData,only:statProg_meta                           ! child metadata for stats
  USE globalData,only:statDiag_meta                           ! child metadata for stats
  USE globalData,only:statFlux_meta                           ! child metadata for stats
  USE globalData,only:statIndx_meta                           ! child metadata for stats
  USE globalData,only:statBvar_meta                           ! child metadata for stats
  USE globalData,only:gru_struc
  USE globalData,only:structInfo                              ! information on the data structures
  USE alloc_file_access,only:alloc_outputStruc
  USE multiconst,only:secprday               ! number of seconds in a day
  USE data_types,only:file_info_array
  USE var_lookup,only:maxvarFreq                ! maximum number of output files
  
  implicit none
  type(file_info_array), pointer        :: forcFileInfo
  integer(i4b), intent(in)              :: maxSteps
  integer(i4b), intent(in)              :: nGRU
  integer(i4b), intent(inout)           :: err 

  ! local variables
  integer(i4b)                          :: nVars
  integer(i4b)                          :: iGRU
  integer(i4b)                          :: iStep
  integer(i4b)                          :: nSnow
  integer(i4b)                          :: nSoil
  integer(i4b)                          :: iStruct
  character(len=256)                    :: message

  ! Allocate structure to hold output files
  if (.not.allocated(outputStructure))then
    allocate(outputStructure(1))
  end if
  ! Statistics Structures
  allocate(outputStructure(1)%forcStat(1))
  allocate(outputStructure(1)%forcStat(1)%gru(nGRU))

  allocate(outputStructure(1)%progStat(1))
  allocate(outputStructure(1)%progStat(1)%gru(nGRU))

  allocate(outputStructure(1)%diagStat(1))
  allocate(outputStructure(1)%diagStat(1)%gru(nGRU))

  allocate(outputStructure(1)%fluxStat(1))
  allocate(outputStructure(1)%fluxStat(1)%gru(nGRU))

  allocate(outputStructure(1)%indxStat(1))
  allocate(outputStructure(1)%indxStat(1)%gru(nGRU))

  allocate(outputStructure(1)%bvarStat(1))
  allocate(outputStructure(1)%bvarStat(1)%gru(nGRU))
  ! Primary Data Structures (scalars)
  allocate(outputStructure(1)%timeStruct(1))
  allocate(outputStructure(1)%timeStruct(1)%gru(nGRU))

  allocate(outputStructure(1)%forcStruct(1))
  allocate(outputStructure(1)%forcStruct(1)%gru(nGRU))

  allocate(outputStructure(1)%attrStruct(1))
  allocate(outputStructure(1)%attrStruct(1)%gru(nGRU))

  allocate(outputStructure(1)%typeStruct(1))
  allocate(outputStructure(1)%typeStruct(1)%gru(nGRU))

  allocate(outputStructure(1)%idStruct(1))
  allocate(outputStructure(1)%idStruct(1)%gru(nGRU))
  ! Primary Data Structures (variable length vectors)
  allocate(outputStructure(1)%indxStruct(1))
  allocate(outputStructure(1)%mparStruct(1))
  allocate(outputStructure(1)%progStruct(1))
  allocate(outputStructure(1)%diagStruct(1))
  allocate(outputStructure(1)%fluxStruct(1))
  allocate(outputStructure(1)%indxStruct(1)%gru(nGRU))
  allocate(outputStructure(1)%mparStruct(1)%gru(nGRU))
  allocate(outputStructure(1)%progStruct(1)%gru(nGRU))
  allocate(outputStructure(1)%diagStruct(1)%gru(nGRU))
  allocate(outputStructure(1)%fluxStruct(1)%gru(nGRU))
  ! Basin-Average structures
  allocate(outputStructure(1)%bparStruct(1))
  allocate(outputStructure(1)%bvarStruct(1))
  allocate(outputStructure(1)%bparStruct(1)%gru(nGRU))
  allocate(outputStructure(1)%bvarStruct(1)%gru(nGRU))
  ! Finalize Stats for writing
  allocate(outputStructure(1)%finalizeStats(1))
  allocate(outputStructure(1)%finalizeStats(1)%gru(nGRU))
  !
  ! Allocate space for HRUs
  !
  do iGRU = 1, nGRU

    ! Get the maximum number of steps needed to initalize the output structure
    nVars = maxval(forcFileInfo%ffile_list(:)%nVars)
    nSnow = gru_struc(iGRU)%hruInfo(1)%nSnow
    nSoil = gru_struc(iGRU)%hruInfo(1)%nSoil

    do iStruct=1,size(structInfo)
      ! allocate space structures
      select case(trim(structInfo(iStruct)%structName))    
        case('time')
          allocate(outputStructure(1)%timeStruct(1)%gru(iGRU)%hru(1)) 
          call alloc_outputStruc(time_meta,outputStructure(1)%timeStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,err=err,message=message)     ! model forcing data
        case('forc')
          allocate(outputStructure(1)%forcStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(forc_meta,outputStructure(1)%forcStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model forcing data
        case('attr')
          allocate(outputStructure(1)%attrStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(attr_meta,outputStructure(1)%attrStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! local attributes for each HRU
        case('type')
          allocate(outputStructure(1)%typeStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(type_meta,outputStructure(1)%typeStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! classification of soil veg etc.
        case('id'  )
          allocate(outputStructure(1)%idStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(id_meta,outputStructure(1)%idStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);        ! local values of hru and gru IDs
        case('mpar')
          allocate(outputStructure(1)%mparStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(mpar_meta,outputStructure(1)%mparStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model parameters
        case('indx')
          allocate(outputStructure(1)%indxStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(indx_meta,outputStructure(1)%indxStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model variables
        case('prog')
          allocate(outputStructure(1)%progStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(prog_meta,outputStructure(1)%progStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model prognostic (state) variables
        case('diag')
          allocate(outputStructure(1)%diagStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(diag_meta,outputStructure(1)%diagStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model diagnostic variables
        case('flux')
          allocate(outputStructure(1)%fluxStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(flux_meta,outputStructure(1)%fluxStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow,nSoil,err,message);    ! model fluxes
        case('bpar')
          call alloc_outputStruc(bpar_meta,outputStructure(1)%bparStruct(1)%gru(iGRU), &
                        maxSteps,nSnow=0,nSoil=0,err=err,message=message);  ! basin-average params 
        case('bvar')
          allocate(outputStructure(1)%bvarStruct(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(bvar_meta,outputStructure(1)%bvarStruct(1)%gru(iGRU)%hru(1), &
                        maxSteps,nSnow=0,nSoil=0,err=err,message=message);  ! basin-average variables
        case('deriv'); cycle
        case default; err=20; message='unable to find structure name: '//trim(structInfo(iStruct)%structName)
      end select
      ! check errors
      if(err/=0)then
        message=trim(message)//'[structure =  '//trim(structInfo(iStruct)%structName)//']'
        return
      endif
    end do  ! looping through data structures

    do iStruct=1,size(structInfo)

      ! allocate space for statistics structures
      select case(trim(structInfo(iStruct)%structName))
        case('forc')
          allocate(outputStructure(1)%forcStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statForc_meta(:)%var_info,outputStructure(1)%forcStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow,nSoil,err,message);    ! model forcing data
        case('prog')
          allocate(outputStructure(1)%progStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statProg_meta(:)%var_info,outputStructure(1)%progStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow,nSoil,err,message);    ! model prognostic 
        case('diag')
          allocate(outputStructure(1)%diagStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statDiag_meta(:)%var_info,outputStructure(1)%diagStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow,nSoil,err,message);    ! model diagnostic
        case('flux')
          allocate(outputStructure(1)%fluxStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statFlux_meta(:)%var_info,outputStructure(1)%fluxStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow,nSoil,err,message);    ! model fluxes
        case('indx')
          allocate(outputStructure(1)%indxStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statIndx_meta(:)%var_info,outputStructure(1)%indxStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow,nSoil,err,message);    ! index vars
        case('bvar')
          allocate(outputStructure(1)%bvarStat(1)%gru(iGRU)%hru(1))
          call alloc_outputStruc(statBvar_meta(:)%var_info,outputStructure(1)%bvarStat(1)%gru(iGRU)%hru(1), &
                                maxSteps,nSnow=0,nSoil=0,err=err,message=message);  ! basin-average variables
        case default; cycle
      end select
    
      ! check errors
      if(err/=0)then
        message=trim(message)//'[statistics for =  '//trim(structInfo(iStruct)%structName)//']'
        return
      endif
    
    end do ! iStruct
    ! Finalize stats structure for writing to output file
    allocate(outputStructure(1)%finalizeStats(1)%gru(iGRU)%hru(1))
    allocate(outputStructure(1)%finalizeStats(1)%gru(iGRU)%hru(1)%tim(maxSteps))
    do iStep = 1, maxSteps
      allocate(outputStructure(1)%finalizeStats(1)%gru(iGRU)%hru(1)%tim(iStep)%dat(1:maxVarFreq))
    end do ! timeSteps
  end do ! Looping through GRUs


end subroutine initalizeOutput


end module