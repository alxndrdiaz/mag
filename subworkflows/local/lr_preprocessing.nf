/*
 * LR_PREPROCESSING: Preprocessing and QC for long reads
 */

include { NANOPLOT as NANOPLOT_RAW                              } from '../../modules/nf-core/nanoplot/main'
include { NANOPLOT as NANOPLOT_FILTERED                         } from '../../modules/nf-core/nanoplot/main'
include { NANOLYSE                                              } from '../../modules/nf-core/nanolyse/main'
include { PORECHOP_ABI                                          } from '../../modules/nf-core/porechop/abi/main'
include { FILTLONG                                              } from '../../modules/local/filtlong'


workflow LR_PREPROCESSING {
    take:
    ch_raw_long_reads         // [ [meta] , fastq] (mandatory)
    ch_short_reads            // [ [meta] , fastq1, fastq2] (mandatory)
    ch_nanolyse_db            // [fasta]

    main:

    ch_versions = Channel.empty()

    NANOPLOT_RAW (
        ch_raw_long_reads
    )

    ch_versions = ch_versions.mix(NANOPLOT_RAW.out.versions.first())

    ch_long_reads = ch_raw_long_reads
                    .map {
                        meta, reads ->
                            def meta_new = meta - meta.subMap('run')
                        [ meta_new, reads ]
                    }

    if ( !params.assembly_input ) {
        if (!params.skip_adapter_trimming) {
            PORECHOP_ABI (
                ch_raw_long_reads
            )
            ch_long_reads = PORECHOP_ABI.out.reads
            ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions.first())
        }

        if (!params.keep_lambda) {
            NANOLYSE (
                ch_long_reads,
                ch_nanolyse_db
            )
            ch_long_reads = NANOLYSE.out.fastq
            ch_versions = ch_versions.mix(NANOLYSE.out.versions.first())
        }

        // join long and short reads by sample name
        ch_short_reads_tmp = ch_short_reads
            .map { meta, sr -> [ meta.id, meta, sr ] }

        ch_short_and_long_reads = ch_long_reads
            .map { meta, lr -> [ meta.id, meta, lr ] }
            .join(ch_short_reads_tmp, by: 0)
            .map { id, meta_lr, lr, meta_sr, sr -> [ meta_lr, lr, sr[0], sr[1] ] }  // should not occur for single-end, since SPAdes (hybrid) does not support single-end

        FILTLONG (
            ch_short_and_long_reads
        )
        ch_long_reads = FILTLONG.out.reads
        ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

        NANOPLOT_FILTERED (
            ch_long_reads
        )
    }

    ch_versions = Channel.empty()
    emit:
    long_reads     = ch_long_reads
    versions    = ch_versions
}
