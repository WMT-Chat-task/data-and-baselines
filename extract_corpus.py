"""
Extracts txt source-only or parallel corpus from a .tsv chat converstion file.
Outputs necessarly two files: (1) source txt file (2) docid file. Optionally, it can output a target txt file aswell.
The docids file contains the "document" identifiers of the segments, where the document depends on the context level.
"""
import argparse
import csv

HEADER = [
  'doc_id', 
  'source_language', 'target_language', 
  'source_segment', 'pe_segment', 'translation_direction'
]

def main():
  parser = argparse.ArgumentParser(description="Extracts .txt parallel corpus from a .tsv chat converstion file")
  parser.add_argument(
    "input_file", 
    type=str,
    help="Input .tsv file"
  )
  parser.add_argument("output_prefix", 
    type=str,
    help="Output prefix the for .txt file(s)"
  )
  parser.add_argument(
    "--direction",
    choices=["customer", "agent"], 
    default="inbound",
    help="Which direction to extract",
  )
  parser.add_argument(
    "--context-level", 
    choices=["segment", "contiguous", "chat"],
    default="segment",
    help="What context level to extract", 
  )
  parser.add_argument("--save-target", action="store_true", help="Save target segments")

  args = parser.parse_args()

  src_lang, tgt_lang = None, None
  srcs, tgts, docids = [], [], []
  with open(args.input_file, "r") as input_file:
    reader = csv.reader(input_file, delimiter=",")

    # check if header matches expected header
    header = next(reader)
    assert header == HEADER, f"Header does not match expected header: {header}"

    # we keep track of two context levels: (1) block level (2) chat level
    curr_blockid = -1
    curr_chatid, curr_chatid_str = -1, None
    prev_direction = None
    for segment_id, row in enumerate(reader):
      chatid_str, seg_src_lang, seg_tgt_lang, src_segment, pe_segment, direction = row
      # increase chatid if needed
      if curr_chatid < 0 or chatid_str != curr_chatid_str:
        curr_chatid_str = chatid_str
        curr_chatid += 1
        prev_direction = None

      # if the direction changes, we increase the block id
      if curr_blockid < 0 or direction != prev_direction:
        curr_blockid += 1
        prev_direction = direction
      
      if direction == args.direction:
        # infer languages from first segment
        if src_lang is None and tgt_lang is None:
          src_lang, tgt_lang = seg_src_lang, seg_tgt_lang
        
        srcs.append(src_segment)
        tgts.append(pe_segment)
        if args.context_level == "segment":
          docids.append(segment_id)
        elif args.context_level == "contiguous":
          docids.append(curr_blockid)
        elif args.context_level == "chat":
          docids.append(curr_chatid)

  src_lang = "pt" if src_lang == "pt-br" else src_lang
  tgt_lang = "pt" if tgt_lang == "pt-br" else tgt_lang

  # save output segments
  src_output = f"{args.output_prefix}.{src_lang}"
  docids_output = f"{args.output_prefix}.docids"
  tgt_output = f"{args.output_prefix}.{tgt_lang}"
  with open(src_output, "w") as src_file, open(docids_output, "w") as docids_file:
    for src, docid in zip(srcs, docids):
      print(src, file=src_file)
      print(docid, file=docids_file)
  if args.save_target:
    with open(tgt_output, "w") as tgt_file:
      for tgt in tgts:
        print(tgt, file=tgt_file)

if __name__ == "__main__":
  main()