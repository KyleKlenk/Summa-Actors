from distutils.command.config import config
import json
import os
import math
from os.path import exists
from datetime import date

"""
Function to create the inital summa_actors_settings file
"""
def create_init_config():
    Settings_file = { 
        "Configuration": {
            "controlVersion": "",
            "simStartTime": "",
            "simEndTime": "",
            "tmZoneInfo": "",
            "settingsPath": "",
            "forcingPath": "",
            "outputPath": "",
            "forcingFreq": "",
            "forcingStart": "",
            "decisionsFile": "",
            "outputControlFile": "",
            "globalHruParamFile": "",
            "globalGruParamFile": "",
            "attributeFile": "",
            "trialParamFile": "",
            "forcingListFile": "",
            "initConditionFile": "",
            "outFilePrefix": "",
            "vegTableFile": "",
            "soilTableFile": "",
            "generalTableFile": "",
            "noahmpTableFile": ""
        },
        
        "JobSubmissionParams": {
            "cpus-per-task": 1,
            "memory": "",
            "job-name": "",
            "account": "",
            "numHRUs": 1,
            "maxNumberOfJobs": 1,
            "maxGRUsPerSubmission": 1,
            "executablePath": ""
            },

        "SummaActor": {
            "OuputStructureSize": 1,
            "maxGRUPerJob": 1
        },

        "FileAccessActor": {
            "num_vectors_in_output_manager": 1
        },
    
        "JobActor": {
            "FileManagerPath": "",
            "outputCSV": "",
            "csvPath": ""
        },

        "HRUActor": {
            "printOutput": "",
            "outputFrequency": 1
        }
    }
    with open('Summa_Actors_Settings.json', 'w') as outfile:
        json.dump(Settings_file, outfile, indent=2)

"""
Function that creates the paths for the slurm output and the netCDF data
"""
def create_output_path(outputPath):
    print("The output path exists, now seperating this run by today's date")
    today = date.today()
    todays_date = today.strftime("%b-%d-%Y")
    outputPath += "{}/".format(todays_date)
    if not exists(outputPath):
        os.mkdir(outputPath)
    print("Directory Created. Now Creating sub directories for SLURM Data and NetCDF data")
    outputNetCDF = outputPath + "netcdf/"
    outputSlurm = outputPath + "slurm/"
    outputCSV = outputPath + "csv/"
    if not exists(outputNetCDF):
        os.mkdir(outputNetCDF)
    if not exists(outputSlurm):
        os.mkdir(outputSlurm)
    if not exists(outputCSV):
        os.mkdir(outputCSV)
    
    # need to add the file name to outputSlurm
    # The job will not be submitted without a file name
    outputSlurm += "slurm-%A_%a.out"
    
    return outputNetCDF, outputSlurm, outputCSV


"""
Function to create the file manager for SummaActors,
THis is a text file that is created from the settings in the Configuration section
in the JSON file.
"""
def create_file_manager():
    json_file = open("Summa_Actors_Settings.json")
    fileManagerSettings = json.load(json_file)
    json_file.close()
    
    # add the date for the run
    outputPath = fileManagerSettings["Configuration"]["outputPath"]
    if exists(outputPath):
        outputNetCDF, outputSlurm, outputCSV = create_output_path(outputPath)
        fileManagerSettings["Configuration"]["outputPath"] = outputNetCDF
    else:
        print("Output path does not exist, Ensure it exists before running this setup")
        return -1
    
    fileManager = open("fileManager.txt", "w")
    for key,value in fileManagerSettings["Configuration"].items():
        fileManager.write(key + "    \'{}\'\n".format(value))
    fileManager.close()

    with open("Summa_Actors_Settings.json") as settings_file:
        data = json.load(settings_file)
        data["JobActor"]["FileManagerPath"] = os.getcwd() + "/" + "fileManager.txt"
        data["JobActor"]["csvPath"] = outputCSV

    with open("Summa_Actors_Settings.json", "w") as updated_settings:
        json.dump(data, updated_settings, indent=2) 


    print("File Manager for this job has been created")
    return outputSlurm


def create_caf_config():
    json_file = open("Summa_Actors_Settings.json")
    SummaSettings = json.load(json_file)
    json_file.close()

    numCPUs = SummaSettings["JobSubmissionParams"]["cpus-per-task"]


    caf_config_name = "caf-application.conf"
    caf_config = open(caf_config_name, "w")
    caf_config.write("caf {{ \n  scheduler {{\n   max-threads = {}\n    }}\n}}".format(numCPUs))
    caf_config.close()
    
    caf_config_path = os.getcwd()
    caf_config_path += "/"
    caf_config_path += caf_config_name
    return caf_config_path


def create_sbatch_file(outputSlurm, configFile):
    json_file = open("Summa_Actors_Settings.json")
    SummaSettings = json.load(json_file)
    json_file.close()

    numCPUs = SummaSettings["JobSubmissionParams"]["cpus-per-task"]
    memory = SummaSettings["JobSubmissionParams"]["memory"]
    jobName = SummaSettings["JobSubmissionParams"]["job-name"]
    account = SummaSettings["JobSubmissionParams"]["account"]
    numberOfTasks = SummaSettings["JobSubmissionParams"]["numHRUs"]
    GRUPerJob = SummaSettings["JobSubmissionParams"]["maxGRUsPerSubmission"]
    executablePath = SummaSettings["JobSubmissionParams"]["executablePath"]

    jobCount = math.ceil(numberOfTasks / GRUPerJob - 1)

    configPath = os.getcwd()

    sbatch = open("run_summa.sh", "w")
    sbatch.write("#!/bin/bash\n")
    sbatch.write("#SBATCH --cpus-per-task={}\n".format(numCPUs))
    sbatch.write("#SBATCH --time=24:00:00\n")
    sbatch.write("#SBATCH --mem={}\n".format(memory))
    sbatch.write("#SBATCH --job-name={}\n".format(jobName))
    sbatch.write("#SBATCH --account={}\n".format(account))
    sbatch.write("#SBATCH --output={}\n".format(outputSlurm))
    sbatch.write("#SBATCH --array=0-{}\n\n".format(jobCount))
    sbatch.write("gruMax={}\n".format(numberOfTasks))
    sbatch.write("gruCount={}\n".format(GRUPerJob))
    sbatch.write("offset=$SLURM_ARRAY_TASK_ID\n")
    sbatch.write("gruStart=$(( 1 + gruCount*offset ))\n")
    sbatch.write("check=$(( $gruStart + $gruCount ))\n")
    sbatch.write("if [ $check -gt $gruMax ]\n")
    sbatch.write("then\n")
    sbatch.write("    gruCount=$(( gruMax-gruStart+1 ))\n")
    sbatch.write("fi\n\n")
    sbatch.write("{} -g ${{gruStart}} -n ${{gruCount}} -c {} --config-file={}".format(executablePath, configPath, configFile))



"""
Funciton checks if the Summa_Actors_Settings.json file exists.
If yes:
    move on
If no:
    create it
"""
def init_run():
    Summa_Settings_Path = './Summa_Actors_Settings.json'
    if exists('./Summa_Actors_Settings.json'):
        print("File Exists, What do we do next")
        outputSlurm = create_file_manager()
        configFile = create_caf_config()
        create_sbatch_file(outputSlurm, configFile)
        

    else:
        print("File Does not Exist and we need to create it")
        create_init_config()       

init_run()