# WMT 2022 Chat Translation Task - Data & Baselines

## Data

The data is provided in csv format, as specified in the official website.
We also provide a script for converting the bitext format commonly used by machine translation frameworks.
This script supports considering different context levels

For example, to extract a bitext for the customer side, considering as context a contiguous sequence of messages (a *block*), run

```bash
mkdir -p data/extracted
python extract_corpus.py \
  data/dev-bilingual.en_$LANG.csv data/extracted/dev \
  --context-level block \
  --direction customer \
  --save-target
```

## Baselines

We provide simple sentence and contextual baselines for the task.
The models are originally sentence-level models that use context through the `contextualizer.py` script.
For more information check the documentation in the script.

### Seting up the environment

Start by installing the correct version of pytorch for your system.
Baselines are run through fairseq.
Install it by running
```bash
git clone https://github.com/pytorch/fairseq
cd fairseq
pip install --editable ./
cd ..
```

The rest of the dependencies are installed by running
```bash
pip install -r requirements.txt
```

### Downloading models

We use the [M2M-100](https://github.com/facebookresearch/fairseq/tree/main/examples/m2m_100) family of models as our baselines.

To download the smallest 418M parameters model, run
```bash
mkdir -p models/m2m_100.418M && cd models/m2m_100.418M
wget https://dl.fbaipublicfiles.com/m2m_100/spm.128k.model
wget https://dl.fbaipublicfiles.com/m2m_100/data_dict.128k.txt
wget https://dl.fbaipublicfiles.com/m2m_100/model_dict.128k.txt
wget https://dl.fbaipublicfiles.com/m2m_100/language_pairs_small_models.txt 
wget https://dl.fbaipublicfiles.com/m2m_100/418M_last_checkpoint.pt model.pt
cd ../..
```

### Running baselines

To run the baseline 418M model with a context size of $N$ for customer side of the English-German data, run
```bash
bash main.sh 
```

This will print various metrics, including BLEU and COMET.

You can edit this file to use a different model, context size or language pair.

More extensive experimentation is based on [ducttape](https://github.com/jhclark/ducttape).
Start by installing it. We recommend installing [version 0.5](https://github.com/CoderPat/ducttape/releases/tag/v0.5)

You can run a sweep over multiple models, context sizes and language pairs by running
```bash
ducttape main.tape -j $NUM_PARALLEL
```

## Submissions converter
Once you get the MT outputs (detruecased, detokenized, etc) you need to add them to the original test CSV file in an extra column, called `mt_segment`.
For this, you can use the `prepare-submission.py` script:

```
python prepare-submission.py \
--csv-file <The original testset CSV FILE> \
--hyp-file <The MT output> \
--output-dir <OUTPUT DIRECTORY> \
--directions <DIRECTIONS>
```

`<The original testset CSV FILE>`: Is the file that you downloaded from the repo containing these columns: `doc_id`,`source_language`,`target_language`,`source_segment`,`translation_direction`.

`<The MT output>`: This file contains the outputs of your MT system after all the postprocessing steps (detruecasing, detokenization, etc). It should contain the translations of the input segments, one per line. In case you are translating both directions at the same time, the translations need to be in the same order as they appear in source side. If you are translating each direction separately, then you will need to call the converter twice, each time with the corresponding MT output and direction (i.e. `customer`|`agent`).
For the file names please check the **Submission Format** section of [our webpage](https://wmt-chat-task.github.io).

`<OUTPUT DIRECTORY>`: The directory to store the final submission files (in CSV format).

`<DIRECTIONS>`: Can take either of `customer` or `agent`. In case your MT output contains the translations of both directions (in the original order of the inputs) you need to specify both directions (i.e. `--directions customer agent`).
