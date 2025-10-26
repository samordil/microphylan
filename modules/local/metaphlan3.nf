process METAPHLAN3 {
    tag "$meta.id"
    label 'process_medium'
    label 'error_ignore'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metaphlan:3.0.12--pyhb7b1952_0' :
        'biocontainers/metaphlan:3.0.12--pyhb7b1952_0' }"

    input:
    tuple val(meta), path(input)
    path metaphlan_db

    output:
    tuple val(meta), path("*_profile.txt"), emit: profile
    tuple val(meta), path("*.biom"), emit: biom
    tuple val(meta), path('*.bowtie2out.txt'), optional:true, emit: bt2out
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ?: "${meta.id}"
    def input_type = (
        "${input}" =~ /.*\.(fastq|fq)(\.gz)?$/  ? "--input_type fastq" :
        "${input}" =~ /.*\.(fasta|fa)$/         ? "--input_type fasta" :
        "${input}".endsWith(".bowtie2out.txt")  ? "--input_type bowtie2out" :
                                                  "--input_type sam"
    )

    // Support multiple FASTQs (paired, unpaired, unmatched, etc.)
    def input_data = (input instanceof List ? input : [input])
                        .collect { it.toString() }
                        .join(",")

    def bowtie2_out = (input_type in ["--input_type bowtie2out", "--input_type sam"]) ? '' : "--bowtie2out ${prefix}.bowtie2out.txt"

    """
    BT2_DB=\$(find -L "${metaphlan_db}" -name "*rev.1.bt2" -exec dirname {} \\; | head -n1)

    metaphlan \\
        --nproc $task.cpus \\
        $input_type \\
        $input_data \\
        --add_viruses \\
        $args \\
        $bowtie2_out \\
        --bowtie2db \$BT2_DB \\
        --biom ${prefix}.biom \\
        --output_file ${prefix}_profile.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metaphlan3: \$(metaphlan --version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """
}
