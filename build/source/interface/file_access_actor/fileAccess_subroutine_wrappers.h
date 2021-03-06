#ifndef fileAccess_SUBROUTINE_WRAPPERS_H_
#define fileAccess_SUBROUTINE_WRAPPERS_H_

extern "C" {
  
  
  void read_pinit_C(int* err);

  void read_vegitationTables(int* err);

  void initFailedHRUTracker(int* numGRU);

  void updateFailed(int* indxHRU);

  void resetFailedArray();

  void resetOutputCounter(int* indxGRU);
  
  void mDecisions_C(int* numSteps, int* err);
  
  void ffile_info_C(int* indxGRU, void* forcFileInfo, int* numFiles, int* err);

  void Init_OutputStruct(void* forcFileInfo, int* maxSteps, int* nGru, int* err);

  void FileAccessActor_ReadForcing(void* forcFileInfo, int* currentFile, int* stepsInFile,
         int* startGRU, int* numGRU, int* err);

  void FileAccessActor_WriteOutput(void* handle_ncid,
        int* stepsInCurrentFile, int*indxGRU, int*indxHRU, int* err);

  void FileAccessActor_DeallocateStructures(void* handle_forcFileInfo, void* handle_ncid);
  
  void Create_Output_File(void* handle_ncid, int* numGRU, int* startGRU, int* err);

  void Write_HRU_Param(void* handle_ncid, int* indxGRU, int* indxHRU, int* err);
}


#endif