//
// amrfinderplus - Identify antimicrobial resistance in genes or proteins
//
include { initOptions } from '../../../lib/nf/functions'
options = initOptions(params.containsKey("options") ? params.options : [:], 'amrfinderplus')
options.is_module = params.wf == 'amrfinderplus' ? true : false
options.args = [
    params.report_common ? "--report_common" : "",
    params.report_all_equal ? "--report_all_equal" : "",
    params.organism ? "--organism ${params.organism}" : "",
    "--ident_min ${params.ident_min}",
    "--coverage_min ${params.coverage_min}",
    "--translation_table ${params.translation_table}",
    "${params.amrfinder_opts}"
].join(' ').replaceAll("\\s{2,}", " ").trim()

AMRFINDER_DB = params.amrfinder_db ? file(params.amrfinder_db) : false

include { AMRFINDERPLUS_UPDATE } from '../../../modules/nf-core/modules/amrfinderplus/update/main' addParams( options: options )
include { AMRFINDERPLUS_RUN } from '../../../modules/nf-core/modules/amrfinderplus/run/main' addParams( options: options )

if (params.is_subworkflow) {
    include { CSVTK_CONCAT as GENES_CONCAT } from '../../../modules/nf-core/modules/csvtk/concat/main' addParams( options: [publish_to_base: true, logs_subdir: 'amrfinderplus-genes'] )
    include { CSVTK_CONCAT as PROTEINS_CONCAT } from '../../../modules/nf-core/modules/csvtk/concat/main' addParams( options: [publish_to_base: true, logs_subdir: 'amrfinderplus-proteins'] )
}

workflow AMRFINDERPLUS {
    take:
    fasta // channel: [ val(meta), [ reads ] ]

    main:
    ch_versions = Channel.empty()
    ch_amrfinder_db = Channel.empty()
    ch_merged_gene_reports = Channel.empty()
    ch_merged_protein_reports = Channel.empty()

    // Sort out the database
    if (AMRFINDER_DB && !params.force_update) {
        // Use the given AMRFinder+ DB
        ch_amrfinder_db = ch_amrfinder_db.mix(AMRFINDER_DB)
    } else {
        // no database given, or forced update
        AMRFINDERPLUS_UPDATE()
        ch_amrfinder_db = ch_amrfinder_db.mix(AMRFINDERPLUS_UPDATE.out.db)
    }

    // Run AMRFinder=
    AMRFINDERPLUS_RUN ( fasta, ch_amrfinder_db )
    ch_versions = ch_versions.mix(AMRFINDERPLUS_RUN.out.versions.first())

    if (params.is_subworkflow) {
        // Merge results if subworkflow
        AMRFINDERPLUS_RUN.out.gene_report.collect{meta, report -> report}.map{ report -> [[id:'amrfinderplus-genes'], report]}.set{ ch_merge_gene_report }
        GENES_CONCAT(ch_merge_gene_report, 'tsv', 'tsv')
        ch_merged_gene_reports = ch_merged_gene_reports.mix(GENES_CONCAT.out.csv)
        ch_versions = ch_versions.mix(GENES_CONCAT.out.versions)

        AMRFINDERPLUS_RUN.out.protein_report.collect{meta, report -> report}.map{ report -> [[id:'amrfinderplus-proteins'], report]}.set{ ch_merge_protein_report }
        PROTEINS_CONCAT(ch_merge_protein_report, 'tsv', 'tsv')
        ch_merged_protein_reports = ch_merged_protein_reports.mix(PROTEINS_CONCAT.out.csv)
        ch_versions = ch_versions.mix(PROTEINS_CONCAT.out.versions)
    }

    emit:
    gene_tsv = AMRFINDERPLUS_RUN.out.gene_report
    merged_gene_tsv = ch_merged_gene_reports
    protein_tsv = AMRFINDERPLUS_RUN.out.protein_report
    merged_protein_tsv = ch_merged_protein_reports
    mutation_reports = AMRFINDERPLUS_RUN.out.mutation_reports
    db = ch_amrfinder_db
    versions = ch_versions // channel: [ versions.yml ]
}
