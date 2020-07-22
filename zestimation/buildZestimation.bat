:: NOTE: This windows batch script builds the Zestimation object files and the executable

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: build ParaMonte library and Zestimation object files and executables
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: silence cmd output

@echo off
cd %~dp0
set ERRORLEVEL=0

echo.
echo. :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo. ::::                                                                                                                       ::::
echo.                                                       Zestimation Build
echo. ::::                                                                                                                       ::::
echo. :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo.

set BUILD_SCRIPT_NAME=zestimation

:: set up compiler version

if not defined COMPILER_VERSION (

    echo. -- !BUILD_SCRIPT_NAME! - Detecting the intel Fortran compiler version...
    cd .\auxil\
    call getCompilerVersion.bat
    cd %~dp0
    echo. -- !BUILD_SCRIPT_NAME! - COMPILER_VERSION: !COMPILER_VERSION!

)

echo.
echo. -- !BUILD_SCRIPT_NAME! - Configuring build...
echo.

call configZestimation.bat
if !ERRORLEVEL!==1 (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: Unable to configure and build Zestimation flags. exiting...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)
cd %~dp0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: generate Zestimation paths
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: add Kfactor correction if needed

set FPP_FLAGS_ZESTIMATION=/define:!LGRB_RATE_MODEL! /define:kfac!KFAC_CORRECTION! 
echo.
echo. -- !BUILD_SCRIPT_NAME! - Kfactor model: !KFAC_CORRECTION!
echo.
echo.
echo. -- !BUILD_SCRIPT_NAME! - Zestimation's Fortran preprocessor macros: !FPP_FLAGS_COSMIC_RATE!
echo.

set MEMORY_ALLOCATION=stack
if !HEAP_ARRAY_ENABLED!==true set MEMORY_ALLOCATION=heap

:: configure the ParaMonte library build

echo.
echo. -- !BUILD_SCRIPT_NAME! - configuring the ParaMonte library build...
echo.

set PARALLELIZATION_DIR=
if !OMP_ENABLED!==true set PARALLELIZATION_DIR=!PARALLELIZATION_DIR!omp
if !MPI_ENABLED!==true set PARALLELIZATION_DIR=!PARALLELIZATION_DIR!mpi
if !CAF_ENABLED!==true set PARALLELIZATION_DIR=!PARALLELIZATION_DIR!caf!CAFTYPE!
if not defined PARALLELIZATION_DIR set PARALLELIZATION_DIR=serial

set CONFIG_PATH=build\win!PLATFORM!\!COMPILER_SUITE!\!COMPILER_VERSION!\!BTYPE!\!LTYPE!\!MEMORY_ALLOCATION!\!PARALLELIZATION_DIR!\!INTERFACE_LANGUAGE!
set ParaMonte_BLD_DIR=%~dp0!ParaMonte_ROOT_DIR!\!CONFIG_PATH!
set ParaMonte_MOD_DIR=!ParaMonte_BLD_DIR!\mod
set ParaMonte_LIB_DIR=!ParaMonte_BLD_DIR!\lib

echo. -- !BUILD_SCRIPT_NAME! - ParaMonte_BLD_DIR: !ParaMonte_BLD_DIR!
echo. -- !BUILD_SCRIPT_NAME! - ParaMonte_MOD_DIR: !ParaMonte_MOD_DIR!
echo. -- !BUILD_SCRIPT_NAME! - ParaMonte_LIB_DIR: !ParaMonte_LIB_DIR!

if exist !ParaMonte_BLD_DIR! (
    echo. -- !BUILD_SCRIPT_NAME! - The ParaMonte library build detected at: !ParaMonte_BLD_DIR!
) else (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: The ParaMonte library build does not exist at: !ParaMonte_BLD_DIR!
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)

:: set and make Zestimation directories

set ZESTIMATION_ROOT_DIR=%~dp0
set ZESTIMATION_BLD_DIR=!ZESTIMATION_ROOT_DIR!!CONFIG_PATH!\kfac!KFAC_CORRECTION!\!LGRB_RATE_MODEL!
set ZESTIMATION_SRC_DIR=!ZESTIMATION_ROOT_DIR!src
set ZESTIMATION_BIN_DIR=!ZESTIMATION_BLD_DIR!\bin
set ZESTIMATION_MOD_DIR=!ZESTIMATION_BLD_DIR!\mod
set ZESTIMATION_OBJ_DIR=!ZESTIMATION_BLD_DIR!\obj
REM set ZESTIMATION_LIB_DIR=!ZESTIMATION_BLD_DIR!\lib

:: loop over Zestimation directories and generate them

echo.
for %%A in (
    !ZESTIMATION_BLD_DIR!
    !ZESTIMATION_BIN_DIR!
    !ZESTIMATION_LIB_DIR!
    !ZESTIMATION_MOD_DIR!
    !ZESTIMATION_OBJ_DIR!
    ) do (  if exist %%A (
                echo. -- !BUILD_SCRIPT_NAME! - %%A already exists. skipping...
            ) else (
                echo. -- !BUILD_SCRIPT_NAME! - generating Zestimation directory: %%A
                mkdir %%A
            )
)
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: setup compile flags
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: set preprocessor build flags

set FPP_BUILD_FLAGS=
if !BTYPE!==debug set FPP_BUILD_FLAGS=/define:DBG_ENABLED

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: set default C/CPP/Fortran compilers/linkers
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

set FPP_FCL_FLAGS=
if !COMPILER_SUITE!==intel (
    set CCL=icl
    set FCL=ifort
    set FPP_FCL_FLAGS=/define:IFORT_ENABLED
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: set up preprocessor flags
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
REM echo. FPP_FLAGS_EXTRA = !FPP_FLAGS_EXTRA!
REM /define:IS_ENABLED
set FPP_FLAGS=/fpp !FPP_CFI_FLAG! !FPP_LANG_FLAG! !FPP_BUILD_FLAGS! !FPP_FCL_FLAGS! !FPP_DLL_FLAGS! !FPP_FLAGS_ZESTIMATION!
REM set FPP_FLAGS=/fpp !FPP_CFI_FLAG! !FPP_LANG_FLAG! !FPP_BUILD_FLAGS! !FPP_FCL_FLAGS! !FPP_DLL_FLAGS! !USER_PREPROCESSOR_MACROS! !FPP_FLAGS_EXTRA!
:: to save the intermediate files use this on the command line: FPP /Qsave_temps <original file> <intermediate file>

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: set up coarray flags
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

echo.
echo. -- !BUILD_SCRIPT_NAME! - setting up Coarray Fortran (CAF) parallelization model. Options: single, shared, distributed
echo. -- !BUILD_SCRIPT_NAME! - requested CAF: !CAFTYPE!

set CAF_ENABLED=false
if !CAFTYPE!==single set CAF_ENABLED=true
if !CAFTYPE!==shared set CAF_ENABLED=true
if !CAFTYPE!==distributed set CAF_ENABLED=true

if !CAF_ENABLED!==true (
    echo. -- !BUILD_SCRIPT_NAME! - enabling Coarray Fortran syntax via preprocesor flag /define:CAF_ENABLED
    set FPP_FLAGS=!FPP_FLAGS! /define:CAF_ENABLED
    set CAF_FLAGS=/Qcoarray=!CAFTYPE!
    if not defined FOR_COARRAY_NUM_IMAGES set FOR_COARRAY_NUM_IMAGES=3
    echo. -- !BUILD_SCRIPT_NAME! - number of Coarray images: !FOR_COARRAY_NUM_IMAGES!
) else (
    echo. -- !BUILD_SCRIPT_NAME! - ignoring Coarray Fortran parallelization.
    set CAF_FLAGS=
    set CAFTYPE=
)

echo. -- !BUILD_SCRIPT_NAME! - Coarray Fortran flags: !CAF_FLAGS!
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: set non-coarray parallelization flags and definitions to be passed to the preprocessors
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

set MPI_FLAGS=
if !MPI_ENABLED!==true (
    if not defined CAFTYPE (
        set FPP_FLAGS=!FPP_FLAGS! /define:MPI_ENABLED
        REM set MPI_FLAGS=-fast
        set FCL=mpiifort.bat -fc=ifort
        set CCL=mpicc -cc=icl.exe
    ) else (
        echo.
        echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: Coarray Fortran cannot be mixed with MPI.
        echo. -- !BUILD_SCRIPT_NAME! - CAFTYPE: !CAFTYPE!
        echo. -- !BUILD_SCRIPT_NAME! - MPI_ENABLED: !MPI_ENABLED!
        echo. -- !BUILD_SCRIPT_NAME! - set MPI_ENABLED and CAFTYPE to appropriate values in the ParaMonte config file and rebuild.
        echo.
        cd %~dp0
        set ERRORLEVEL=1
        exit /B 1
    )
)

set OMP_FLAGS=
if !OMP_ENABLED!==true set OMP_FLAGS=/Qopenmp
set FCL_PARALLELIZATION_FLAGS=!CAF_FLAGS! !MPI_FLAGS! !OMP_FLAGS!
echo. -- !BUILD_SCRIPT_NAME! - all compiler/linker parallelization flags: !FCL_PARALLELIZATION_FLAGS!
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: set set default Fortran compiler flags in different build modes.
:: Complete list of intel compiler options:
:: https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-alphabetical-list-of-compiler-options
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if !COMPILER_SUITE!==intel (

    ::  /QxHost
    set FCL_FLAGS_DEFAULT=/nologo /standard-semantics /F0x1000000000

    if !BTYPE!==debug set FCL_BUILD_FLAGS=!INTEL_FORTRAN_DEBUG_FLAGS! /stand:f08

    if !BTYPE!==release set FCL_BUILD_FLAGS=!INTEL_FORTRAN_RELEASE_FLAGS!

    :: set Fortran linker flags for release mode
    if !BTYPE!==release set FL_FLAGS=/Qopt-report:2
    if !BTYPE!==testing set FL_FLAGS=
    if !BTYPE!==debug   set FL_FLAGS=
    REM /Qipo-c:
    REM      Tells the compiler to optimize across multiple files and generate a single object file ipo_out.obj without linking
    REM      info at: https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-ipo-c-qipo-c
    REM

    if !BTYPE!==testing set FCL_BUILD_FLAGS=!INTEL_FORTRAN_TESTING_FLAGS!

) else (

    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: No compiler other than Intel Parallel Studio is suppoerted on Windows. exiting...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1

)

set FCL_FLAGS=!FCL_FLAGS_DEFAULT! !FCL_PARALLELIZATION_FLAGS! !FCL_BUILD_FLAGS!

if !HEAP_ARRAY_ENABLED!==true (
    set FCL_FLAGS=!FCL_FLAGS! /heap-arrays
)

echo.
echo. -- !BUILD_SCRIPT_NAME! - Fortran preprocessor flags: !FPP_FLAGS!
echo. -- !BUILD_SCRIPT_NAME! - Fortran linker library flags: !FL_LIB_FLAGS!
echo. -- !BUILD_SCRIPT_NAME! - Fortran compiler library flags: !FC_LIB_FLAGS!
echo. -- !BUILD_SCRIPT_NAME! - Fortran compiler/linker all flags: !FCL_FLAGS!
echo. -- !BUILD_SCRIPT_NAME! - Fortran compiler/linker default flags: !FCL_FLAGS_DEFAULT!
echo. -- !BUILD_SCRIPT_NAME! - Fortran compiler/linker flags in !BTYPE! build mode: !FCL_BUILD_FLAGS!
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: generate Zestimation object files
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if !ZESTIMATION_OBJ_BUILD_ENABLED! NEQ true (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Warning: skipping Zestimation object files build...
    echo.
    goto LABEL_ZESTIMATION_EXE_BUILD_ENABLED
)
:: Read the name of each file from the ordered list of filenames in filelist.txt to compile

cd !ZESTIMATION_OBJ_DIR!
echo.
echo. -- !BUILD_SCRIPT_NAME! - building Zestimation program...

:: First verify the source filelist exists

set FILE_LIST=!ZESTIMATION_SRC_DIR!\filelist.txt
if not exist !FILE_LIST! (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: The filelist.txt containing the Zestimation source filenames does not exist. Path: !FILE_LIST!
    echo. -- !BUILD_SCRIPT_NAME! - build failed. exiting...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)

for /F "eol=! tokens=*" %%A in (!FILE_LIST!) do (

    echo. -- !BUILD_SCRIPT_NAME! - generating object file for %%A

    !FCL! !FCL_FLAGS! !FPP_FLAGS! ^
    /module:!ZESTIMATION_MOD_DIR!       %=path to output Zestimation module files=% ^
    /I:!ZESTIMATION_MOD_DIR!            %=path to output Zestimation module files, needed 4 dependencies=%  ^
    /I:!ParaMonte_MOD_DIR!              %=path to input Astronomy library module files=%  ^
    /c !ZESTIMATION_SRC_DIR!\%%A        %=path to input Zestimation source file=%  ^
    || (
        echo.
        echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: compilation of the object file for %%A failed.
        echo. -- !BUILD_SCRIPT_NAME! - build failed. exiting...
        echo.
        set ERRORLEVEL=1
        cd %~dp0
        set ERRORLEVEL=1
        exit /B
    )
)
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: generate Zestimation executable
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:LABEL_ZESTIMATION_EXE_BUILD_ENABLED

if !ZESTIMATION_EXE_BUILD_ENABLED! NEQ true (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Warning: skipping Zestimation exectuable build...
    echo.
    goto LABEL_ZESTIMATION_RUN_ENABLED
)

echo.

set ZESTIMATION_EXECUTABLE_NAME=!LGRB_RATE_MODEL!.exe

if !LTYPE!==dynamic (

    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Warning: dynamically-linked Zestimation executable not implemented. This requires significant changes in the library interfaces.
    echo. -- !BUILD_SCRIPT_NAME! - generating statically-linked Zestimation executable at: !ZESTIMATION_BIN_DIR!
    echo.

    REM  copy necessary DLL files in the Zestimation executable's directory

    echo. -- !BUILD_SCRIPT_NAME! - copying the ParaMonte library files to the Zestimation executable directory...
    echo. -- !BUILD_SCRIPT_NAME! - from: !ParaMonte_LIB_DIR!\    %= no need for final slash here =%
    echo. -- !BUILD_SCRIPT_NAME! -   to: !ZESTIMATION_BIN_DIR!   %= final slash tells this is folder =%
    xcopy /s /Y "!ParaMonte_LIB_DIR!" "!ZESTIMATION_BIN_DIR!\"
    echo.

    echo. -- !BUILD_SCRIPT_NAME! - generating dynamically-linked Zestimation executable at: !ZESTIMATION_BIN_DIR!


    set REQUIRED_OBJECT_FILES=!ZESTIMATION_OBJ_DIR!\*.obj !ParaMonte_LIB_DIR!\*.lib
    set FCL_FLAGS=!FCL_FLAGS! /align:commons

) else (    %= static linking requested =%

    echo. -- !BUILD_SCRIPT_NAME! - generating statically-linked Zestimation executable at: !ZESTIMATION_BIN_DIR!
    set REQUIRED_OBJECT_FILES=!ZESTIMATION_OBJ_DIR!\*.obj !ParaMonte_LIB_DIR!\*.lib

)

:: delete the old executable first

echo. deleting old executable (if any) at: !ZESTIMATION_BIN_DIR!\!ZESTIMATION_EXECUTABLE_NAME!

cd !ZESTIMATION_BIN_DIR!

del !ZESTIMATION_EXECUTABLE_NAME!
if !ERRORLEVEL!==1 (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: deletion of the old executable at !ZESTIMATION_BIN_DIR!\!ZESTIMATION_EXECUTABLE_NAME! failed. exiting...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)

:: build the executable

echo.
echo. -- !BUILD_SCRIPT_NAME! - Compilation command: !FCL! !FCL_FLAGS! !FL_FLAGS! ^
/module:!ZESTIMATION_MOD_DIR! ^
/I:!ZESTIMATION_MOD_DIR! /I:!ParaMonte_MOD_DIR! ^
!REQUIRED_OBJECT_FILES! ^
/exe:!ZESTIMATION_BIN_DIR!\!ZESTIMATION_EXECUTABLE_NAME!

echo.

!FCL! !FCL_FLAGS! !FL_FLAGS! ^
/module:!ZESTIMATION_MOD_DIR! ^
/I:!ZESTIMATION_MOD_DIR! /I:!ParaMonte_MOD_DIR! ^
!REQUIRED_OBJECT_FILES! ^
/exe:!ZESTIMATION_BIN_DIR!\!ZESTIMATION_EXECUTABLE_NAME!

if !ERRORLEVEL!==1 (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Fatal Error: linking of the Zestimation object files may have likely failed.
    echo. -- !BUILD_SCRIPT_NAME! - build may have likely failed. continuing...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)

echo.
echo. -- !BUILD_SCRIPT_NAME! - the binary directory: !ZESTIMATION_BIN_DIR!
echo.

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: run Zestimation executable
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:LABEL_ZESTIMATION_RUN_ENABLED

:: run Zestimation
:: if !ZESTIMATION_RUN_ENABLED! NEQ true goto LABEL_EXAMPLE_BUILD_ENABLED
if !ZESTIMATION_RUN_ENABLED! NEQ true (
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Warning: skipping Zestimation run...
    echo.
    goto :eof
)

echo.
echo. :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo. ::::                                                                                                                       ::::
echo.                                             Running Zestimation
echo. ::::                                                                                                                       ::::
echo. :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo.

:: copy necessary input files in the executable's directory
echo. copying input files to the Zestimation executable's directory
echo. from: !ZESTIMATION_ROOT_DIR!\in   %= no need for final slash here =%
echo.   to: !ZESTIMATION_BIN_DIR!\in\  %= final slash tells this is folder =%
xcopy /s /Y "!ZESTIMATION_ROOT_DIR!\in" "!ZESTIMATION_BIN_DIR!\in\"

set SAMPLE_FILE_ROOT=C:\Users\joshu_s8uy48a\Dropbox\Projects\BatseLgrbRedshiftCatalog\git\cosmicRate\build\linuxx64\intel\18.0.2.199\release\static\mpi
if !LGRB_RATE_MODEL!==H06 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdH06\romberg\bin\out\ParaDRAM_run_20200315_231042_506_process_1_sample.txt
if !LGRB_RATE_MODEL!==L08 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdL08\romberg\bin\out\ParaDRAM_run_20200316_183919_024_process_1_sample.txt
if !LGRB_RATE_MODEL!==B10 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdB10\romberg\bin\out\ParaDRAM_run_20200312_060333_408_process_1_sample.txt
if !LGRB_RATE_MODEL!==M14 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdM14\romberg\bin\out\ParaDRAM_run_20200319_011001_166_process_1_sample.txt
if !LGRB_RATE_MODEL!==M17 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdM17\romberg\bin\out\ParaDRAM_run_20200313_032933_429_process_1_sample.txt
if !LGRB_RATE_MODEL!==F18 set SAMPLE_FILE_PATH=!SAMPLE_FILE_ROOT!\kfacOneThirdF18\romberg\bin\out\ParaDRAM_run_20200314_021639_172_process_1_sample.txt
echo.
echo.
echo. -- !BUILD_SCRIPT_NAME! - sample file path: !SAMPLE_FILE_PATH!
echo.

cd !ZESTIMATION_BIN_DIR!
!ZESTIMATION_EXECUTABLE_NAME! ./in/ Zestimation.nml !SAMPLE_FILE_PATH! && (
    echo.
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Zestimation run successful.
    echo.
) || (
    echo.
    echo.
    echo. -- !BUILD_SCRIPT_NAME! - Zestimation run failed. exiting...
    echo.
    cd %~dp0
    set ERRORLEVEL=1
    exit /B 1
)


cd %~dp0

set ERRORLEVEL=0
exit /B 0
