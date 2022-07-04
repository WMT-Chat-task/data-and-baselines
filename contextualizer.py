from typing import List, Optional, Tuple

import sys
import argparse
import json
from collections import Counter

def split_corpus(
  blocked_corpus: List[str],
  block_info: List[int], 
  break_tag: str="madeupword0000",
  fallback_strategy: Optional[str] = "last_empty",
) -> List[str]:
  """ Extracts outputs from translation prompted with context. """
  corpus = []
  error = 0
  for block, num_sentences in zip(blocked_corpus, block_info):
    sentences = [s for s in block.split(break_tag) if s.strip()]
    if len(sentences) > num_sentences:
      corpus += [sent.strip() for sent in sentences[-num_sentences:]]
    elif len(sentences) == num_sentences:
      corpus += [sent.strip() for sent in sentences]
    else:
      error += 1
      corpus += [sent.strip() for sent in sentences]
      corpus += ["." for _ in range(num_sentences - len(sentences))]
  
  print("Warning: {} sentences were dropped".format(error), file=sys.stderr)
  return corpus

def contextualize_corpus(
  corpus: List[str],
  docids: List[int],
  context_size: int,
  block_size: int,
  break_tag: str=" madeupword0000 ",
) -> Tuple[List[str], List[int]]:
  """ Contextualizes a corpus with multiple segments for contextual translation."""
  prev_docid = -1

  block_info = []
  blocked_corpus = []

  def next_block(block: List[str]) -> List[str]:
    block_info.append(len(block))
    blocked_corpus.append(break_tag.join(block))
    return []
  
  block: List[str] = []
  for sent, docid in zip(corpus, docids):
    if docid != prev_docid:
      prev_docid = docid
      block = next_block(block) if block else []

    block.append(sent)
    if len(block) == block_size:
      block = next_block(block)

  if block:
    next_block(block)

  return blocked_corpus, block_info
    


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument(
    "mode", 
    choices=["contextualize", "split"],
    help="What mode to run the script in. Two modes are available: `contextualize` and `split`."
      "TODO(coderpat): further documentation"
  )
  parser.add_argument("input_file", help="Path to input file to contextualize or split")
  parser.add_argument("output_file", help="Path to output contextualized or splitted file")
  parser.add_argument("--docids", type=str, required=True)
  parser.add_argument("--block-info", type=str, required=True)
  parser.add_argument("--context-size", type=int, default=0)
  parser.add_argument("--block-size", type=int, default=None)
  args = parser.parse_args()

  with open(args.input_file) as inp_f:
    inputs = [l.strip() for l in inp_f.readlines()]
  with open(args.docids) as docids_f:
    docids = [int(l.strip()) for l in docids_f.readlines()]

  # TODO(patick): explain
  if args.mode == "contextualize":
    args.block_size = (args.context_size + 1
              if args.block_size is None 
              else args.block_size)

    assert (args.context_size >= -1 
       and args.block_size >= 0 
       and args.block_size <= args.context_size+1), ( 
      "context_size must be non-negative and compatible with block size")

    blocked_corpus, block_info = contextualize_corpus(
      corpus=inputs,
      docids=docids,
      context_size=args.context_size,
      block_size=args.block_size,
    )
    with open(args.output_file, "w") as out_f:
      for block in blocked_corpus:
        print(block, file=out_f)
    with open(args.block_info, "w") as out_f:
      json.dump(block_info, out_f)
  # TODO(patick): explain
  elif args.mode == "split":
    with open(args.block_info, "r") as inp_f:
      block_info = json.load(inp_f)
    splitted_corpus = split_corpus(
      blocked_corpus=inputs, 
      block_info=block_info
    )
    assert len(splitted_corpus) == len(docids)
    with open(args.output_file, "w") as out_f:
      for sent in splitted_corpus:
        print(sent, file=out_f)


if __name__ == "__main__":
  main()