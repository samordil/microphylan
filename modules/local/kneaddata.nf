process KNEADDATA {
    tag "$sample_id"
    label 'process_medium'

    container "${workflow.containerEngine == 'singularity' || workflow.containerEngine == 'apptainer' ? 
    'oras://community.wave.seqera.io/library/kneaddata:0.12.3--720d316ad753dc36' : 
    'community.wave.seqera.io/library/kneaddata:0.12.3--f1697b109e76c058'}"

    input:
    tuple val(sample_id), path(read1), path(read2)
    path ref_db

    output:
    path "${sample_id}/*_paired_1.fastq"                    , emit: paired_r1
    path "${sample_id}/*_paired_2.fastq"                    , emit: paired_r2
    path "${sample_id}/*_unmatched_1.fastq"                 , emit: unmatched_r1
    path "${sample_id}/*_unmatched_2.fastq"                 , emit: unmatched_r2
    path "${sample_id}/*.log"                               , emit: kneaddata_log
    path "${sample_id}/fastqc/*_1_fastqc.zip"               , emit: fastqc_pre_r1
    path "${sample_id}/fastqc/*_2_fastqc.zip"               , emit: fastqc_pre_r2
    path "${sample_id}/fastqc/*_paired_1_fastqc.zip"        , emit: fastqc_post_paired_r1
    path "${sample_id}/fastqc/*_paired_2_fastqc.zip"        , emit: fastqc_post_paired_r2
    path "${sample_id}/fastqc/*_unmatched_1_fastqc.zip"     , emit: fastqc_post_unmatched_r1
    path "${sample_id}/fastqc/*_unmatched_2_fastqc.zip"     , emit: fastqc_post_unmatched_r2
    path "versions.yml"                                     , emit: versions

    script:
        """
        kneaddata \\
            --input1 $read1 \\
            --input2 $read2 \\
            --reference-db $ref_db \\
            --sequencer-source TruSeq3 \\
            --max-memory ${task.memory.toMega()}M \\
            --threads $task.cpus \\
            --output $sample_id \\
            --output-prefix $sample_id \\
            --bypass-trf \\
            --run-fastqc-start \\
            --run-fastqc-end

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            kneaddata: \$(kneaddata --version 2>&1 | sed -e "s/kneaddata //g")
        END_VERSIONS
        """
    }

