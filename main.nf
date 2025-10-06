#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import modules
include { SAMPLESHEET_GENERATION                } from './modules/local/generate_samplesheet'
include { KNEADDATA                             } from './modules/local/kneaddata' 
include { FASTP                                 } from './modules/nf-core/fastp/main'
include { MULTIQC  as MULTIQC_PRE               } from './modules/nf-core/multiqc/main'
include { MULTIQC  as MULTIQC_POST_PAIRED       } from './modules/nf-core/multiqc/main'
include { MULTIQC  as MULTIQC_POST_UNMATCHED    } from './modules/nf-core/multiqc/main'
include { METAPHLAN                             } from './modules/local/metaphlan.nf'


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

    // Define bowtie index human genome directory and make it a value channel
    channel
        .value(file(params.human_genome))
        .set { ch_host_genome }

    // Define metaphlan4 db directory and make it a value channel
    channel
        .value(file(params.metaphlan_db))
        .set { ch_metaphlan_db }

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

    // Prepare samplesheet for kneaddata tool
    SAMPLESHEET_GENERATION.out.samplesheet
        .splitCsv(header:true)
        .map { row -> tuple( row.id, file(row.r1), file(row.r2)) }
        .set { ch_samplesheet }

    // Do QC and depletion of human reads using kneaddata from biobakery
    KNEADDATA (
        ch_samplesheet,
        ch_host_genome
    )

    // Run QC on Pre-trimmed fastq files
    KNEADDATA.out.fastqc_pre_r1.map{it[1]}
        .mix( KNEADDATA.out.fastqc_pre_r2.map{it[1]})
	    .collect()
        .set { ch_fasqc_pre }
    MULTIQC_PRE (
        ch_fasqc_pre,
        'pre_qc',
        [],[],[],[],[]
    )

    // Run QC on post-trimmed paired 
    KNEADDATA.out.fastqc_post_paired_r1.map{it[1]}
        .mix( KNEADDATA.out.fastqc_post_paired_r2.map{it[1]})
	    .collect()
        .set { ch_fasqc_post_paired }
    MULTIQC_POST_PAIRED (
        ch_fasqc_post_paired,
        'post_qc_paired',
        [],[],[],[],[]
    )

    // Run QC on post-trimmed post trimmed unmatched
    KNEADDATA.out.fastqc_post_unmatched_r1.map{it[1]}
        .mix( KNEADDATA.out.fastqc_post_unmatched_r2.map{it[1]})
	    .collect()
        .set { ch_fasqc_post_unmatched }
    MULTIQC_POST_UNMATCHED (
        ch_fasqc_post_unmatched,
        'post_post_unmatched',
        [],[],[],[],[]
    )

    // Combine all kneaddata FASTQ outputs by sample ID
    // Combine all four KNEADDATA outputs into one channel per sample
    KNEADDATA.out.paired_r1
        .mix(
            KNEADDATA.out.paired_r2,
            KNEADDATA.out.unmatched_r1,
            KNEADDATA.out.unmatched_r2
        )
        .groupTuple(by: 0)
        .map { sample_id, files ->
            // Convert to the format MetaPhlAn expects:
            // meta: [id: sample_id], files: list of fastqs
            tuple([id: sample_id], files.flatten().unique())
        }
        .set { ch_kneaddata_non_host_fastqs }


    ch_kneaddata_non_host_fastqs.view()

    METAPHLAN_METAPHLAN (
        ch_kneaddata_non_host_fastqs,
        ch_metaphlan_db,
        false
    )

    METAPHLAN_METAPHLAN.out.profile_txt.view()
/*
    // Prepare samplesheet for fastp tool
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
*/

}
