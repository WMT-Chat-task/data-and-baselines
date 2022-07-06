
#!/bin/bash
set -euo pipefail

DATA_DIR=data
LANG="de"
DIRECTION="customer"
CONTEXT_LEVEL="contiguous"
CONTEXT_SIZE=5
COMET_DIR="/projects/tir1/users/pfernand/comet-v3/"
MODEL_DIR="/projects/tir6/general/pfernand/models/m2m_100.418M"

extracted_dir=${DATA_DIR}/extracted
mkdir -p ${extracted_dir}

python extract_corpus.py \
  ${DATA_DIR}/dev-bilingual.en_${LANG}.csv ${extracted_dir}/dev \
  --context-level $CONTEXT_LEVEL \
  --direction $DIRECTION \
  --save-target

if [[ "$LANG" == "pt-br" ]] ; then
  LANG="pt"
fi

if [[ "${DIRECTION}" == "customer" ]]; then
    tgt_lang=en
    src_lang=$LANG
else
    tgt_lang=$LANG
    src_lang=en
fi

python contextualizer.py contextualize \
  ${extracted_dir}/dev.${src_lang} /tmp/blocked_src \
  --docids ${extracted_dir}/dev.docids \
  --block-info /tmp/block_info \
  --context-size $CONTEXT_SIZE

python fairseq/scripts/spm_encode.py \
  --model ${MODEL_DIR}/spm.128k.model \
  --output_format=piece \
  --inputs=/tmp/blocked_src \
  --outputs=/tmp/prep_src

mkdir -p /tmp/bin_dir
fairseq-interactive \
  /tmp/bin_dir \
  --input /tmp/prep_src \
  --buffer-size 1000 \
  --batch-size 8 \
  --path ${MODEL_DIR}/model.pt \
  --fixed-dictionary ${MODEL_DIR}/model_dict.128k.txt \
  -s $src_lang -t $tgt_lang \
  --remove-bpe 'sentencepiece' \
  --beam 5 \
  --task translation_multi_simple_epoch \
  --lang-pairs ${MODEL_DIR}/language_pairs_small_models.txt \
  --decoder-langtok --encoder-langtok src \
  --fp16 > /tmp/full_outputs

cat /tmp/full_outputs | grep ^H | cut -c 3- | sort -n | cut -f3- > /tmp/blocked_pred

predictions_dir=${DATA_DIR}/extracted
mkdir -p ${predictions_dir}
python contextualizer.py split \
  /tmp/blocked_pred ${predictions_dir}/dev.pred.${tgt_lang} \
  --docids ${extracted_dir}/dev.docids \
  --block-info /tmp/block_info 

python score.py \
  ${predictions_dir}/dev.pred.${tgt_lang} ${extracted_dir}/dev.${tgt_lang} \
  --src ${extracted_dir}/dev.${src_lang} \
  --comet-dir $COMET_DIR