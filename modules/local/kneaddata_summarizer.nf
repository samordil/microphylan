process KNEADDATA_LOG_SUMMARIZER {
    tag "summarize kneaddata logs"
    label 'process_single'

    container "${workflow.containerEngine == 'singularity' || workflow.containerEngine == 'apptainer' ? 
    'oras://community.wave.seqera.io/library/python:3.13.7--4b3e29a9ac2bf898' : 
    'community.wave.seqera.io/library/python:3.13.7--b46958bde3c7e023'}"

    input:
    path kneaddata_log_file

    output:
    path "kneaddata_log_summary.csv"           , emit: csv
    path "versions.yml"                         , emit: versions

    script:
        """
        kneaddata_log_summarizer.py \\
            --input $kneaddata_log_file \\
            --output kneaddata_log_summary.csv \\

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python --version 2>&1 | sed -e "s/Python //g")
        END_VERSIONS
        """
    }
