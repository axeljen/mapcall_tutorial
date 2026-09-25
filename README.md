# map_and_call tutorial

This is a small tutorial on how to use my nextflow pipeline map_and_call to process, map and call WGS data.

I'll also include some tutorials on what we can do with the actual output of the pipeline.

## Get started

First off, clone this repo and download the data:

```bash
    # navigate to a folder in which you want to download the tutorial
    cd /path/to/folder # change this path to someplace where you want to store and run the tutorial, for example a dedicated directory in your project folder.
    
    # clone the tutorial repository, and enter it
    git clone https://github.com/axeljen/mapcall_tutorial
    cd map_and_call_tutorial
```

When that's done, you should have the tutorial repository cloned and the data downloaded, and we're ready to start.

## Download the data

The data we'll use in this tutorial is a small simulated set of a reference genome and WGS, illumina-like paired-end reads for 50 individuals from 5 populations (PopA-PopE). The data is hosted publicly available on osf, and can be downloaded with the following command:

```bash

    # download the archived data folder
    curl -L https://osf.io/download/fn2gc/ -o data.tar

    # and extract the data
    tar -xf data.tar

    # now we can remove the archive to save space and keep the folder clean
    rm data.tar

    # inspect the structure of the data dir, we can use tree, a tool to visualize the directory structure, for this purpose
    ml tree # tree isn't in path by default on dardel,  so we need to load it as a module

    tree data

```

A bit messy, but we can see that the data folder contains the subfolders reads and reference, where the reads folder contains the paired-end sequencing data files (two files per sample), and the reference folder contains the reference genome (reference_genome.fa.gz). This is all the data we need to run the pipeline.

## Run map_and_call

First thing we need to do is to clone the latest version of map_and_call from github. Let's do that:

```bash
    # ensure that you're located in the tutorial folder:
    pwd
    # this should show the path to the tutorial folder, e.g. /path/to/folder/map_and_call_tutorial, otherwise first navigate to the tutorial folder
    
    # next, we clone the nextflow pipeline from github
    git clone https://github.com/axeljen/map_and_call

```

The map_and_call repo should contain the following files and directories (double check with:)

```bash
    ls -1 map_and_call
```

    bin
    entry_points
    lib
    main.nf
    modules
    nextflow.config
    README.md
    run_locally.sh
    run_on_arrhenius.sh
    run_on_dardel.sh
    run_on_pelle.sh
    sample_sheet.csv
    subworkflows

Depending on what infrastructure you are running this pipeline on, you may be able to use one of the preconfigured slurm scripts (run_on_*.sh). If you're not on slurm, you can use the run_locally.sh script. If you're on a different slurm cluster than these, you should be able to adapt one of the ready-made slurm scripts for your needs: the relevant changes that you'll need to adapt are:
- Slurm headers (i.e., #SBATCH lines), as these may differ between clusters. Specifically the partition (-p) and the account (-A) lines will very likely differ

- The module load lines, as these will depend on what modules are available on your cluster. You can check which modules are available by running `module avail` on your cluster. If you'd rather (or need to) install the dependencies yourself, then you need to install [nextflow](https://www.nextflow.io/) and [conda](https://docs.conda.io/en/latest/miniconda.html) amd make sure that these are accessible in your PATH.

For the rest of this tutorial, we'll assume that you're working on dardel, and modify the run_on_dardel.sh script to suite our needs.

### Prepare the sample sheet

The sample sheet is the most important input to the pipeline (along with the reference genome), and likely the most tedious part to prepare. It must contain five columns separated by semi-colon, and the first line should be the header. You may have noticed above that there's a sample sheet included in the repository that we just cloned. It's empty with only the header line, so we can use that as a template. 

Let's copy it into our current directory, and give it a name that indicates that it's not simply the template:

```bash
    cp map_and_call/sample_sheet.csv sample_sheet_tutorial.csv
```

Since we've downloaded all the data into the data/ directory, we could manually parse through each read pair and add the relevant information to the sample sheet by hand. This is likely to be necessary in some cases, but to avoid typoes, sample mixups etc., it's always good to automate wherever possible! So for the sake of learning, we'll generate the sample sheet lines with some bash scripting:

``` bash
    # check filenames of the reads:
    find data/reads
    # an example of a read pair name is:
    ## ind1_popA_R1.fq.gz, ind1_popA_R2.fq.gz
    # the info that we need from each read pair:
    # 1) sample name; in this case this will be everything before the first underscore in the read file name (e.g., ind1 in the example above)
    # 2) library id (all these reads are simulated, single-library data, so we can just call everything lib1). If you're working with data where several libraries have been sequenced for the same sample, you need to make sure that the library id is unique for each library
    # 3) data type: 1 = modern, 2 = museum/historical data. All our read data is "modern".
    # 4) read 1; this is the path to the read 1 file. We can either specify this as the full relative path (i.e., data/reads/ind1_popA_R1.fq.gz), or just the file basename (i.e., ind1_popA_R1.fq.gz) and provide the --reads_dir data/reads argument to the pipeline. We'll do the latter, as this keeps the sample sheet a little cleaner.
    # 5) read 2; this is the path to the read 2 file, and the same rules apply as for read 1.

    # now we just loop through all the read 1 files, and extract the sample name and add all info to the sample sheet:
    for read1 in $(find data/reads -name "*_R1.fq.gz")
        do
            # extract the sample name from the read 1 file name
            sample_name=$(basename $read1 | cut -d "_" -f 1)
            # extract the read 2 file name from the read 1 file name
            read2=$(echo $read1 | sed 's/_R1.fq.gz/_R2.fq.gz/')
            # add a line to the sample sheet
            echo "$sample_name;lib1;1;$(basename $read1);$(basename $read2)" >> sample_sheet_tutorial.csv
        done
    # make sure that the sample sheet looks correct:
    head sample_sheet_tutorial.csv
 
```

This prints the first 10 lines of the sample sheet, and should look like this: if all went well

    sample_id;library;data_type;read_1;read_2
    ind25;lib1;1;ind25_popC_R1.fq.gz;ind25_popC_R2.fq.gz
    ind28;lib1;1;ind28_popC_R1.fq.gz;ind28_popC_R2.fq.gz
    ind11;lib1;1;ind11_popB_R1.fq.gz;ind11_popB_R2.fq.gz
    ind49;lib1;1;ind49_popE_R1.fq.gz;ind49_popE_R2.fq.gz
    ind9;lib1;1;ind9_popA_R1.fq.gz;ind9_popA_R2.fq.gz
    ind10;lib1;1;ind10_popA_R1.fq.gz;ind10_popA_R2.fq.gz
    ind27;lib1;1;ind27_popC_R1.fq.gz;ind27_popC_R2.fq.gz
    ind39;lib1;1;ind39_popD_R1.fq.gz;ind39_popD_R2.fq.gz
    ind36;lib1;1;ind36_popD_R1.fq.gz;ind36_popD_R2.fq.gz

That's all for the sample sheet!

### Prepare the slurm script

The main nextflow script is called main.nf, and when we run this with one of the default slurm profiles (in this case the dardel profile), this process will submit all of the different processes as independent slurm jobs. We could, in principle, run the main process directly in an interactive terminal, but since the pipeline takes a while to run, we'd need to make sure that the terminal session lives to see the end of the pipeline, else it will fail. A better approach is to submit the main process itself as a slurm job, and this is what we'll do through one of the preconfigured slurm scripts.

Let's copy the run_on_dardel.sh script into our current directory, and start preparing it for our needs:

```bash
    cp map_and_call/run_on_dardel.sh run_on_dardel_tutorial.sh

    # inspect the content
    cat run_on_dardel_tutorial.sh
```

As you'll see, there are a bunch of things we need to change in there. If you're working on for example vscode where you can edit the script directly in a text editor, you can just go ahead and make the changes manually. But again, for the sake of practicing bash, I'll take you through the possibiltiy of editing this script entirely through the command line:

```bash
    # we'll use the sed command (stream editor) to make the changes in the script. With the -i flag, we can edit the file in place.

    # first thing to set is the slurm account, as this is specified by the placeholder <NAISS_COMPUTE_PROJECT> in the slurm script. I will be using the account naiss2026-4-730 here, but you need to use an account that you're a part of and that's allowed to run jobs on dardel (or whichever cluster you're using).
    account_to_use=naiss2026-4-730 #edit this line, as it defines a variable with the account to use, and we'll just reference the variable in the next line.
    sed -i "s/<NAISS_COMPUTE_PROJECT>/$account_to_use/g" run_on_dardel_tutorial.sh
    # next, we need to set the path to the sample sheet, by replacing the placeholder 'path/to/input.csv' with the path to the sample sheet that we just created. Since it's in the current directory, we can just use the name of the file. To let sed know that the slashes in the path are not to be interpreted as delimiters, we need to use "escape" characters (backslashes) before each slash in the path. 
    sed -i "s/\/path\/to\/input.csv/sample_sheet_tutorial.csv/g" run_on_dardel_tutorial.sh

    # next the reference genome, which is located at data/reference/reference_genome.fa.gz, and placeheld in the template by '/path/to/reference_genome.fa':
    sed -i "s/\/path\/to\/reference_genome.fa/data\/reference\/reference_genome.fa.gz/g" run_on_dardel_tutorial.sh

    # the argument we mentioned before, namely the directory where all our reads are stored:
    sed -i "s/\/path\/to\/reads_directory/data\/reads/g" run_on_dardel_tutorial.sh

    # an optional argument to the pipeline is the scaffold_list, which is a simple text file just listing the scaffolds or chromosomes in the reference genome that we want to perform variant calling on.
    # since this is a small simulated genome, we will include all scaffolds, and in principle we could then just omit this option. But we can also prepare a list of all chromosomes in the reference genome, and just pass this one:
    zcat data/reference/reference_genome.fa.gz | grep ">" | sed 's/>//g' > data/reference/scaffold_list.txt
    
    # now:
    cat data/reference/scaffold_list.txt
    # should give you a list of all chromosomes in the simulated genome, chr1-chr10
    # let's replace the placeholder in the slurm script with the path to this file:
    sed -i "s/\/path\/to\/scaffolds.txt/data\/reference\/scaffold_list.txt/g" run_on_dardel_tutorial.sh

    # let's set a path to where we want to store the output of the pipeline, too:
    sed -i "s/\/path\/to\/output_directory/output_tutorial/g" run_on_dardel_tutorial.sh

    # now one final thing. Since we'll be executing the pipeline from this directory, not from the actual map_and_call folder, we need to adjust the path to the main.nf script in the slurm script, so the computer knows where to find the main script:
    sed -i "s/main.nf/map_and_call\/main.nf/g" run_on_dardel_tutorial.sh

    # double check that all our changes came through:
    cat run_on_dardel_tutorial.sh

    export CONDA_PKG_DIR=/cfs/klemming/projects/supr/naiss2025-23-567/dev/mapcall_tutorial/map_and_call/.envs/pkgs

    # if all looks correct, we're ready to ship the job to slurm!
    sbatch run_on_dardel_tutorial.sh

```
Slurm jobs will log progress in two files, one for stdout and one for stderr. We've specified the location of these files in the slurm headers of our script:
    
    #SBATCH -o ./logs/%x-%j.out
    #SBATCH -e ./logs/%x-%j.error

The .out is stdout and .error is stderr. The %x and %j are placeholders that automatically will expand to the job name and job id, respectively. So for example, if the job name is map-and-call, as it will be in this case unless you've changed the slurm header for the job name (\#SBATCH -J map-and-call), the stdout file will be called map-and-call-<job_id>.out, and the stderr file will be called map-and-call-<job_id>.error. The jobid is automatically assigned by slurm upon submission, and will be unique for each job. Note that we place these files in a separate, child directory, logs/. This is just for the purpose of keeping the directory a bit cleaner, and the logs directory will be automatically created by slurm if it doesn't already exist.

To quickly monitor the progress of the pipeline, we can check running/queued slurm jobs with:

    ```bash
    squeue -u $USER
    ```
    
    Don't be scared if this shows tons of jobs, the pipeline spawns a lot of independent jobs, like processing of each individual read pair and whatnot, so that's normal. For more detailed information about the progress, we can have a look in the stdout file:

    ```bash
    # find the most recent stdout file in the logs directory:
    ls -1tr logs/*.out | tail -n 1 # the following flags were added to ls here: -1 = list one file per line, -t = sort by modification time, -r = reverse order (so the most recent file is last). Typing this as ls -1 -t -r is equivalent to ls -1tr

    # Nextflow stdout becomes a bit messy when written to a file like this, but a neat thing we can do is to monitor the last part of the file in real time, with less:
    less +F $(ls -1tr logs/*.out | tail -n 1)
    
    ```

A snapshot of this less output can look like this:
    
    executor >  slurm (152)
    [34/520f07] IND…x (reference_genome.fa.gz) | 1 of 1 ✔
    [af/5c1df4] IND…x (reference_genome.fa.gz) | 1 of 1 ✔
    [34/3c1c2c] IND…CE:dochunks (refintervals) | 1 of 1 ✔
    [0b/42e364] PRE…RN:fastqc_rawreads (ind37) | 50 of 50 ✔
    [88/c65381] PRE…SS_MODERN:multiqc_rawreads | 1 of 1 ✔
    [e3/785caf] PRE…OCESS_MODERN:fastp (ind35) | 50 of 50 ✔
    [-        ] PREPROCESS_MODERN:concat_reads -
    [64/08cacb] PRE…RN:clumpify_paired (ind29) | 50 of 50 ✔
    [de/81e05c] PRE…:fastqc_cleanreads (ind41) | 39 of 50
    [-        ] PRE…_MODERN:multiqc_cleanreads -
    [-        ] PRE…HISTORICAL:fastqc_rawreads -
    [-        ] PRE…ISTORICAL:multiqc_rawreads -
    [-        ] PRE…_HISTORICAL:adapterremoval -
    [-        ] PRE…SS_HISTORICAL:concat_reads -
    [-        ] PRE…ISTORICAL:concat_collapsed -
    [-        ] PRE…HISTORICAL:clumpify_paired -
    [-        ] PRE…HISTORICAL:clumpify_single -
    [-        ] PRE…STORICAL:fastqc_cleanreads -
    [-        ] PRE…TORICAL:multiqc_cleanreads -
    [09/cb930c] MAP_MODERN:bwa_mem (ind7)      | 26 of 50

Here you can follow the progress of the pipeline: Some of the processes only run once and are already finished, for example:

    [34/520f07] IND…x (reference_genome.fa.gz) | 1 of 1, cached: 1 ✔

The text is unfortunately truncated here, but this process is the indexing of the reference genome – which only has to be done once, prior to mapping, and for this relatively small simulated genome it's rather quick so in this case it's already finished. 

Other processes run once per sample, e.g.,:

    [e3/785caf] PRE…OCESS_MODERN:fastp (ind35) | 50 of 50 ✔

This is the trimming/cleaning of the read files with the program fastp, and the 50 of 50 means that this process was scheduled to run 50 times, once for each sample in our sample sheet. The check mark at the end indicates that this process is already finished for all samples. 

As the pipeline progresses, you may see other numbers here too, as some processes will parallelize across genomic regions etc., so the scheduled number of times they run may vary.

As nextflow executes the pipeline, it will write all the intermeditate files that each of the processes create into a dedicated directory. This is called the workdir, and by default it will be located in the folder where we execute the pipeline from. So if you do:


    ls -1

You should now see that a directory named "work" has been created. 

This folder can become very large when the pipeline is applied to real datasets, which can potentially cause problems if there's limited storage space on the project directory where the pipeline is run. If there is a temporary/scratch storage system available on the cluster where you're running the pipeline, it may therefore be a good idea to tell nextflow to use the temporary storage for this directory. Note that the tempstorage need to be accessible to across compute nodes, so we cannot use node-specific scratch storage which is the only thing available on some slurm clusters (Uppmax, for example). On dardel, however, we can accomplish this by adding the following flag to the pipeline execution inside the slurm script:


    -work-dir $PDC_TMP/map_and_call_workdir


