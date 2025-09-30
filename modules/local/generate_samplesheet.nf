process SAMPLESHEET_GENERATION {
    tag "generate samplesheet"
    label 'process_single'

    container "${workflow.containerEngine == 'singularity' || workflow.containerEngine == 'apptainer' ? 
    'oras://community.wave.seqera.io/library/python:3.13.7--4b3e29a9ac2bf898' : 
    'community.wave.seqera.io/library/python:3.13.7--b46958bde3c7e023'}"

    input:
    path data_dir
    path metadata

    output:
    path "samplesheet.csv"           , emit: samplesheet
    path "versions.yml"              , emit: versions

    script:
    def metadata_csv = metadata ? "--mapping ${metadata}" : ""

        """
        samplesheet.py \\
            --directory $data_dir \\
            --output samplesheet.csv \\
            $metadata_csv

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python --version 2>&1 | sed -e "s/Python //g")
        END_VERSIONS
        """
    }

