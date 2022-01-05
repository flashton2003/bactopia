//
// mashdist - Calculate Mash distances between sequences
//
ask_merlin = params.containsKey('ask_merlin') ? params.ask_merlin : false
include { initOptions } from '../../../lib/nf/functions'
options = initOptions(params.containsKey("options") ? params.options : [:], 'mashdist')
options.is_module = params.wf == 'mashdist' ? true : false
options.args = [
    "-v ${params.max_p}",
    ask_merlin || params.wf == "merlin" ? "-d ${params.merlin_dist}" : "-d ${params.max_dist}",
    "-w ${params.mash_w}",
    "-m ${params.mash_m}",
    "-S ${params.mash_seed}"
].join(' ').replaceAll("\\s{2,}", " ").trim()
options.ignore = [".fna", ".fna.gz", "fastq.gz", ".genus"]

MASH_SKETCH = []
if (ask_merlin || params.wf == "merlin") {
    if (ask_merlin) {
        MASH_SKETCH = file("${params.datasets}/minmer/mash-refseq-k21.msh")
    } else {
        MASH_SKETCH = file(params.mash_sketch)
    }
    include { MERLIN_DIST as MERLINDIST_MODULE } from '../../../modules/nf-core/modules/mash/dist/main' addParams( options: options )
} else {
    MASH_SKETCH = file(params.mash_sketch)
    include { MASH_DIST as MASHDIST_MODULE  } from '../../../modules/nf-core/modules/mash/dist/main' addParams( options: options )
}

workflow MASHDIST {
    take:
    seqs // channel: [ val(meta), [ reads or assemblies ] ]

    main:
    ch_versions = Channel.empty()

    MASHDIST_MODULE(seqs, MASH_SKETCH)
    ch_versions = ch_versions.mix(MASHDIST_MODULE.out.versions.first())

    emit:
    dist = MASHDIST_MODULE.out.dist
    versions = ch_versions // channel: [ versions.yml ]
}

workflow MERLINDIST {
    take:
    seqs // channel: [ val(meta), [ reads or assemblies ] ]

    main:
    ch_versions = Channel.empty()

    MERLINDIST_MODULE(seqs, MASH_SKETCH)
    ch_versions = ch_versions.mix(MERLINDIST_MODULE.out.versions.first())

    emit:
    dist = MERLINDIST_MODULE.out.dist
    escherichia = MERLINDIST_MODULE.out.escherichia
    haemophilus = MERLINDIST_MODULE.out.haemophilus
    klebsiella  = MERLINDIST_MODULE.out.klebsiella
    listeria = MERLINDIST_MODULE.out.listeria
    mycobacterium = MERLINDIST_MODULE.out.mycobacterium
    mycobacterium_fq = MERLINDIST_MODULE.out.mycobacterium_fq
    neisseria = MERLINDIST_MODULE.out.neisseria
    salmonella = MERLINDIST_MODULE.out.salmonella
    staphylococcus = MERLINDIST_MODULE.out.staphylococcus
    streptococcus  = MERLINDIST_MODULE.out.streptococcus
    versions = ch_versions // channel: [ versions.yml ]
}