process METAPHLAN {
    tag "${meta.id}"
    label 'process_medium'
    label 'error_ignore'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/metaphlan:4.2.2--pyhdfd78af_0'
        : 'biocontainers/metaphlan:4.2.2--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(input)
    path metaphlan_db_latest
    val save_samfile

    output:
    tuple val(meta), path("*_profile.txt")      , emit: profile_txt
    tuple val(meta), path("*.biom")             , optional: true    , emit: biom_table
    tuple val(meta), path("*.mapout")           , optional: true    , emit: mapout
    tuple val(meta), path("*.sam")              , optional: true    , emit: sam_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"

    // Detect input type
    def input_type = (
        "${input}" =~ /.*\.(fastq|fq)$/     ? "--input_type fastq"  :
        "${input}" =~ /.*\.(fasta|fna|fa)$/ ? "--input_type fasta"  :
        "${input}".endsWith(".mapout")      ? "--input_type mapout" :
                                              "--input_type sam"
    )

    // Handle one or multiple FASTQs
    def input_data = (input instanceof List ? input : [input])
                        .collect { it.toString() }
                        .join(",")

    // Output controls
    def mapout_opt  = (input_type in ["--input_type mapout", "--input_type sam"]) ? '' : "--mapout ${prefix}.mapout"
    def samfile_opt = save_samfile ? "-s ${prefix}.sam" : ''

    """
    BT2_DB=\$(find -L "${metaphlan_db_latest}" -name "*rev.1.bt2*" -exec dirname {} \\; | head -n1)
    BT2_DB_INDEX=\$(find -L ${metaphlan_db_latest} -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///' | head -n1)

    metaphlan ${input_data} ${input_type} \\
        --nproc ${task.cpus} \\
        ${mapout_opt} \\
        ${samfile_opt} \\
        --db_dir \$BT2_DB \\
        --index \$BT2_DB_INDEX \\
        ${args} \\
        --biom_format_output ${prefix}.biom \\
        --output_file ${prefix}_profile.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metaphlan: \$(metaphlan --version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """
}
