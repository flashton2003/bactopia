nextflow.enable.dsl = 2

// Assess cpu and memory of current system
include { get_resources; initOptions; saveFiles } from '../../../../lib/nf/functions'
RESOURCES = get_resources(workflow.profile, params.max_memory, params.max_cpus)
options = initOptions(params.containsKey('options') ? params.options : [:], 'minmer_sketch')
options.ignore = [".fastq.gz"]

process MINMER_SKETCH {
    /*
    Create minmer sketches of the input FASTQs using Mash (k=21,31),
    Sourmash (k=21,31,51), and McCortex (k=31)
    */
    tag "${meta.id}"
    label "base_mem_8gb"
    label "minmer_sketch"

    publishDir "${params.outdir}/${meta.id}", mode: params.publish_dir_mode, overwrite: params.force,
        saveAs: { filename -> saveFiles(filename:filename, opts:options) }

    input:
    tuple val(meta), path(fq)

    output:
    tuple val(meta), path(fq), path("${meta.id}.sig"), emit: sketch
    path("${meta.id}*.{msh,sig}")
    path("${meta.id}.ctx"), optional: true
    path "*.{log,err}", emit: logs, optional: true
    path ".command.*", emit: nf_logs
    path "versions.yml", emit: versions

    shell:
    fastq = meta.single_end ? fq[0] : "${fq[0]} ${fq[1]}"
    mccortex_fq = meta.single_end ? "-1 ${fq[0]}" : "-2 ${fq[0]}:${fq[1]}"
    m = task.memory.toString().split(' ')[0].toInteger() * 1000 - 500
    '''
    gzip -cd !{fastq} | mash sketch -o !{meta.id}-k21 -k 21 -s !{params.sketch_size} -r -I !{meta.id} -
    gzip -cd !{fastq} | mash sketch -o !{meta.id}-k31 -k 31 -s !{params.sketch_size} -r -I !{meta.id} -
    sourmash sketch dna -p k=21,k=31,k=51,abund,scaled=!{params.sourmash_scale} --merge !{meta.id} -o !{meta.id}.sig !{fastq}

    if [[ "!{params.count_31mers}" == "true" ]]; then
        mccortex31 build -f -k 31 -s !{meta.id} !{mccortex_fq} -t !{task.cpus} -m !{m}mb -q temp_counts
        if [ "!{params.keep_singletons}" == "false" ]; then
            # Clean up Cortex file (mostly remove singletons)
            mccortex31 clean -q -B 2 -U2 -T2 -m !{m}mb -o !{meta.id}.ctx temp_counts
            rm temp_counts
        else
            mv temp_counts !{meta.id}.ctx
        fi
    fi

    # Capture versions
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        mash: $(echo $(mash 2>&1) | sed 's/^.*Mash version //;s/ .*$//')
        mccortex: $(echo $(mccortex31 2>&1) | sed 's/^.*mccortex=v//;s/ .*$//')
        sourmash: $(echo $(sourmash --version 2>&1) | sed 's/sourmash //;')
    END_VERSIONS
    '''
}
