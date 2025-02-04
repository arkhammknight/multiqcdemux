#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.outdir = 'results'

process run_r_script {
    publishDir "${params.outdir}", mode: 'copy'
    container 'ghcr.io/arkhammknight/multiqcdemux:latest'

    input:
    path sample_sheet
    path demux_stats
    path run_info

    output:
    path "Reports/*.html", emit: reports, optional: true
    path "r_script_output.log", emit: log

    script:
    """
    mkdir -p Reports
    echo "Current directory: \$(pwd)"
    echo "Contents of current directory:"
    ls -la
    echo "Contents of /usr/src/app:"
    ls -la /usr/src/app
    echo "R version:"
    R --version
    echo "Installed R packages:"
    R -e "installed.packages()[,c(1,3)]"
    echo "Running R script..."
    Rscript /usr/src/app/2demux_ss_sinan.R ${sample_sheet} ${demux_stats} ${run_info} 2>&1 | tee r_script_output.log
    echo "R script execution completed"
    echo "Contents of r_script_output.log:"
    cat r_script_output.log
    echo "Contents of Reports directory:"
    ls -la Reports/
    """
}

workflow {
    // Input channels
    ch_samples = Channel.fromPath("../Reports/SampleSheet.csv")
    ch_stats = Channel.fromPath("../Reports/Demultiplex_Stats.csv")
    ch_run_info = Channel.fromPath("../Reports/RunInfo.xml")
    
    // Run R script
    run_r_script(ch_samples, ch_stats, ch_run_info)
}