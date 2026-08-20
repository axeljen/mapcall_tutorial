# map_and_call tutorial

This is a small tutorial on how to use my nextflow pipeline map_and_call to process, map and call WGS data.

I'll also include some tutorials on what we can do with the actual output of the pipeline.

## Get started

First off, clone this repo and download the data:

```bash
    # navigate to a folder in which you want to download the tutorial
    cd /path/to/folder
    
    # clone the tutorial repository, and enter it
    git clone /address/to/repo
    cd map_and_call_tutorial
```

When that's done, you should have the tutorial repository cloned and the data downloaded, and we're ready to start.

## Download the data

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
    zcat data/reference/reference_genome.fa.gz | grep ">" | sed 's/>//g' > data/reference/scaffold_list.
    txt
    # now:
    cat data/reference/scaffold_list.txt
    # should give you a list of all chromosomes in the simulated genome, chr1-chr10
    # let's replace the placeholder in the slurm script with the path to this file:
    sed -i "s/\/path\/to\/scaffolds.txt/data\/reference\/scaffold_list.txt/g" run_on_dardel_tutorial.sh

    # let's set a path to where we want to store the output of the pipeline, too:
    sed -i "s/\/path\/to\/output_directory/output_tutorial/g" run_on_dardel_tutorial.sh

    # now one final thing. Since we'll be executing the pipeline from this directory, not from the actual map_and_call folder, we need to adjust the path to the main.nf script in the slurm script, so the computer knows where to find the main script:
    sed -i "s/main.nf/\map_and_call\/main.nf/g" run_on_dardel_tutorial.sh

    sbatch run_on_dardel_tutorial.sh