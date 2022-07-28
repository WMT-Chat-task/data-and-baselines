#!/usr/bin/env python3
import argparse
import pandas as pd
import lxml.etree as ET

def main():
    parser = argparse.ArgumentParser(
        description="Create the final submission from the hypothesis file and the original test CSV.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--csv-file",
        help="The original CSV test file that contains all the test conversations.",
    )
    parser.add_argument(
        "--hyp-file",
        help="The text file containing the MT outputs. It can contain either the translations of one side or both.",
    )
    parser.add_argument(
        "--output-dir",
        help="The output dir to store the final CSV file.",
    )
    parser.add_argument(
        "--directions",
        nargs='+',
        default="agent",
        help="The direction(s) that you want to submit the translations ([agent, customer]) .",
    )
    args = parser.parse_args()
    directions = args.directions    
    # Read the original CSV file
    reader = pd.read_csv(args.csv_file, sep=',')
    # Read the hypothesis file
    with open(args.hyp_file, "r") as hyps:
        translations = hyps.readlines()
        translations = [translation.strip() for translation in translations]
    no_directions = len(directions)
    
    if no_directions == 1:
        direction = directions[0]
        reader.loc[reader['translation_direction']==direction, 'mt_segment'] = translations
    elif no_directions == 2:
        reader['mt_segment'] = translations
    else:
        print(f"ERROR: We have only 2 directions, but you specified {no_directions}.")
        exit(1)
    reader.to_csv(f"{args.output_dir}/{args.csv_file}.csv",index='False')
    print(f"{args.output_dir}/{args.csv_file} updated.")
if __name__ == "__main__":
    main()