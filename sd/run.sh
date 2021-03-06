. path.sh
. cmd.sh

magicdata_test_path=/home/chenyifan/repos/sd-magicdata/wav/ # add your own path
work_dir=./data/magicdata160h_dev_test
sad_dir=$work_dir/sad_part
sad_work_dir=$sad_dir/exp
sad_result_dir=$sad_dir/sad
dia_dir=$work_dir/dia_part
dia_vad_dir=$dia_dir/vad
dia_rttm_dir=$dia_dir/rttm
dia_emb_dir=$dia_dir/embedding
dia_split_rttm_dir=$dia_dir/splited_rttm
dia_stable_rttm_dir=$dia_dir/stable_rttm

mkdir -p $work_dir || exit 1;
mkdir -p $sad_dir || exit 1;
mkdir -p $sad_work_dir || exit 1;
mkdir -p $sad_result_dir || exit 1;
mkdir -p $dia_dir || exit 1;
mkdir -p $dia_vad_dir || exit 1;
mkdir -p $dia_rttm_dir || exit 1;
mkdir -p $dia_emb_dir || exit 1;
mkdir -p $dia_split_rttm_dir || exit 1;
mkdir -p $dia_stable_rttm_dir || exit 1;

stage=1
nj=8

if [ $stage -le 1 ]; then
    # Prepare the magicdata data
    echo "Prepare Magicdata data"
    scripts/make_magicdata_test.sh $magicdata_test_path $work_dir
    
    cp $work_dir/init_wav.scp $work_dir/wav.scp
    awk '{print $1" "$1}' $work_dir/wav.scp > $work_dir/utt2spk
    awk '{print $1" "$1}' $work_dir/wav.scp > $work_dir/spk2utt

    sad_feat=$sad_dir/feat/mfcc
    cp $work_dir/wav.scp $sad_dir
    cp $work_dir/utt2spk $sad_dir
    cp $work_dir/spk2utt $sad_dir

    utils/fix_data_dir.sh $sad_dir
    # extract feature
    scripts/extract_feature.sh $sad_dir $sad_feat $nj
fi

if [ $stage -le 2 ]; then
    # Do Speech Activity Detectation
    echo "Do SAD"
    ## do the segmentations
    scripts/do_segmentation.sh $sad_dir $sad_work_dir $sad_result_dir $nj

    ## filter segments
    # python scripts/filter_vad.py --input_segments $sad_dir/sad_seg/segments \
    #                              --output_segments $sad_dir/sad_seg/filtered_segments
fi

if [ $stage -le 3 ]; then
    # The Speaker Embedding Extractor
    # The VBx tools need a special sad result, so convert the segments file to that format
    echo "Do Speaker Embedding Extractor"
    cp $work_dir/wav.scp $dia_dir

    python scripts/segment_to_lab.py --input_segments $sad_dir/sad_seg/segments \
                                     --label_path $dia_vad_dir \
                                     --output_label_scp_file $dia_dir/label.scp

    # The scripts only use the cpu here
    # If you want to use the gpu to extract the speaker embedding,
    # please check the `scripts/extract_embeddings_gpu.sh`
    # Note that the scripts will sub all the job, so please keep the `exit 1`
    scripts/extract_embeddings.sh $dia_dir $magicdata_test_path
fi

if [ $stage -le 4 ]; then
    # The Speaker Embedding Cluster
    echo "Do the Speaker Embedding Cluster"
    # The meeting data is long so that the cluster is a little bit slow
    scripts/run_cluster.sh $dia_dir
fi
