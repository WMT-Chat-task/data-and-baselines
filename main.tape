global {
  ducttape_output="/projects/tir6/general/pfernand/workflow-outputs/wmt22-chat-bzlines/"
  ducttape_experimental_submitters=true
  ducttape_experimental_imports=true
  ducttape_experimental_multiproc=true
  repo="/home/pfernand/repos/data-and-baselines/data-and-baselines"

  data_dir="/home/pfernand/repos/data-and-baselines/data-and-baselines/data"
  model_dir=(Model:
    large="/projects/tir6/general/pfernand/models/m2m_100.1B"
    small="/projects/tir6/general/pfernand/models/m2m_100.418M"
  )
  comet_dir="/projects/tir1/users/pfernand/comet-v3/"
  context_level="contiguous"
  context_size=(ContextSize: 0 1 2 3 5 -1)
  block_size=(BlockSize: none="" 1)
  direction=(Direction: "customer" "agent")
  src_lang="en"
  tgt_lang=(Lang: de fr pt)

  .exclude="tir-0-3,tir-0-7" 
}

task ExtractCorpus 
   < data_dir=@
   > extracted_dir
  :: repo=@
  :: context_level=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
{
  if [[ "$tgt_lang" == "pt" ]]; then
    tgt_lang="pt-br"
  fi

  mkdir $extracted_dir
  python ${repo}/extract_corpus.py \
    ${data_dir}/dev-bilingual.${src_lang}_${tgt_lang}.csv ${extracted_dir}/dev \
    --context-level $context_level \
    --direction $direction \
    --save-target
}

task ContextualizeSource
   < extracted_dir=@ExtractCorpus
   > blocked_src
   > block_info
  :: repo=@
  :: context_size=@
  :: block_size=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
{
  set -e # exit on error
  if [[ "${direction}" == "customer" ]]; then
    tmp=$tgt_lang
    tgt_lang=$src_lang
    src_lang=$tmp
  fi
  
  python ${repo}/contextualizer.py contextualize \
    ${extracted_dir}/dev.${src_lang} $blocked_src \
    --docids ${extracted_dir}/dev.docids \
    --block-info $block_info \
    --context-size $context_size \
    $([ ! -z "$block_size"  ] && echo "--block-size $block_size" || echo "") 
}

task PreprocessSource
   < blocked_src=@ContextualizeSource
   > prep_src
   > bin_dir
  :: repo=@
  :: model_dir=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
{
  set -e # exit on error
  if [[ "${direction}" == "customer" ]]; then
    tmp=$tgt_lang
    tgt_lang=$src_lang
    src_lang=$tmp
  fi

  python ${repo}/fairseq/scripts/spm_encode.py \
    --model ${model_dir}/spm.128k.model \
    --output_format=piece \
    --inputs=$blocked_src \
    --outputs=$prep_src
  mkdir $bin_dir
}

task GenerateTranslations
   < prep_src=@PreprocessSource
   < bin_dir=@PreprocessSource
   > blocked_pred
  :: repo=@
  :: model_dir=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
  :: .submitter="slurm" .mem=64Gb .gres="gpu:A6000:1" .exclude=@
{
  if [[ "${direction}" == "customer" ]]; then
    tmp=$tgt_lang
    tgt_lang=$src_lang
    src_lang=$tmp
  fi
  fairseq-interactive \
    $bin_dir \
    --input $prep_src \
    --buffer-size 1000 \
    --batch-size 8 \
    --path ${model_dir}/model.pt \
    --fixed-dictionary ${model_dir}/model_dict.128k.txt \
    -s $src_lang -t $tgt_lang \
    --remove-bpe 'sentencepiece' \
    --beam 5 \
    --task translation_multi_simple_epoch \
    --lang-pairs ${model_dir}/language_pairs_small_models.txt \
    --decoder-langtok --encoder-langtok src \
    --fp16 > full_outputs

  cat full_outputs | grep ^H | cut -c 3- | sort -n | cut -f3- > $blocked_pred
}

task SplitDecoded
   < extracted_dir=@ExtractCorpus
   < blocked_pred=@GenerateTranslations
   < block_info=@ContextualizeSource
   > split_pred
  :: repo=@
  :: context_size=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
{
  set -e # exit on error
  if [[ "${direction}" == "customer" ]]; then
    lang=$src_lang
  elif [[ "${direction}" == "agent" ]]; then
    lang=$tgt_lang
  fi
  
  python ${repo}/contextualizer.py split \
    $blocked_pred $split_pred \
    --docids ${extracted_dir}/dev.docids \
    --block-info $block_info 
}

task ScoreTranslations
   < extracted_dir=$extracted_dir@ExtractCorpus
   < pred=$split_pred@SplitDecoded
   > scores
  :: repo=@
  :: comet_dir=@
  :: direction=@
  :: src_lang=@
  :: tgt_lang=@
  :: .submitter="slurm" .mem=32Gb .gres="gpu:1" .exclude=@
{
  if [[ "${direction}" == "customer" ]]; then
    tmp=$tgt_lang
    tgt_lang=$src_lang
    src_lang=$tmp
  fi

  python ${repo}/score.py \
    $pred ${extracted_dir}/dev.${tgt_lang} \
    --src ${extracted_dir}/dev.${src_lang} \
    --comet-dir $comet_dir > $scores
}

summary TranslationQuality {
  of ScoreTranslations >  bleu comet chrf ter {
    cat $scores | grep -oP "COMET = \K[-0-9.]+" > $comet
    cat $scores | grep -oP "BLEU = \K[-0-9.]+" > $bleu
    cat $scores | grep -oP "chrF2 = \K[-0-9.]+" > $chrf
    cat $scores | grep -oP "TER = \K[-0-9.]+" > $ter
   }
}

plan Small {
  reach ScoreTranslations via (Model: small) * (Lang: *) * (ContextSize: *) * (Direction: *)
}

plan Large {
  reach ScoreTranslations via (Model: large) * (Lang: *) * (ContextSize: *) * (Direction: *)
}