#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { SAMPLESHEET_GENERATION    } from './modules/local/generate_samplesheet'
include { FASTP                     } from './modules/nf-core/fastp/main'
include { MULTIQC                   } from './modules/nf-core/multiqc/main' 


workflow {

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                        DEFINE DATA INPUT CHANNELS
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Define input channel for an optional tsv metadata file
    if (params.metadata) { ch_metadata = file(params.metadata) } else { ch_metadata = [] }


    // Define fastq_pass directory channel
    Channel                                                     // Get raw fastq directory
        .fromPath(params.fastq_dir, type: 'dir', maxDepth: 1)
        .set { ch_fastq_data_dir }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    END OF DATA INPUT CHANNEL DEFINATIONS
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Generate samplesheet
    SAMPLESHEET_GENERATION (
        ch_fastq_data_dir,
        ch_metadata
    )

    SAMPLESHEET_GENERATION.out.samplesheet
        .splitCsv(header:true)
        .map { row -> tuple( [id: row.id, single_end: false], tuple(file(row.r1), file(row.r2)), [] ) }
        .set { ch_samplesheet }

    // Filtering and trimming
    FASTP (
        ch_samplesheet,          // [ id, [r1, r2], [] ]
        false,
        false,
        false
    )

    // Aggregate QC report
    FASTP.out.json.map{it[1]}
        .mix( FASTP.out.log.map{it[1]})
	.collect()
        .set { ch_fastp_qc_files }

    // Run multiqc
     MULTIQC (
        ch_fastp_qc_files,
        [],[],[],[],[]
   )
}
