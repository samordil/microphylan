process METAPHLAN_MERGEMETAPHLANTABLES {
    label 'process_single'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/metaphlan:4.2.2--pyhdfd78af_0'
        : 'biocontainers/metaphlan:4.2.2--pyhdfd78af_0'}"

    input:
    path(profiles)

    output:
    path "metaphlan_merged_file.txt"        , emit: txt
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    merge_metaphlan_tables.py \\
        $args \\
        -o metaphlan_merged_file.txt \\
        ${profiles}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metaphlan: \$(metaphlan --version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """
}