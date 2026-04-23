# Data sources:
# Google Ngrams (2020 English 1-grams):
# https://storage.googleapis.com/books/ngrams/books/20200217/eng/eng-1-ngrams_exports.html
#
# Word list (JSON):
# https://github.com/dwyl/english-words/blob/master/words_dictionary.json

import gzip
import pandas as pd
import os
import time
import sys
import re


def process_chunk(chunk):
    """Process a chunk of lines from the gzip file."""
    data = []
    for line in chunk.splitlines():
        if not line:  # Skip empty lines
            continue
        values = line.strip().split("\t")
        if len(values) < 2:  # Ensure there's data beyond the word
            continue
        word = values[0]

        # Remove addendums like _NOUN, _ADJ, etc and make everything lowercase
        word = word.split("_")[0].lower()

        # Skip words with non-alphabetic characters
        if not word.isalpha():
            continue

        if not re.match("^[A-Za-z]+$", word):
            continue

        data_points = values[1:]

        # Pre-filter data points for the last 25 years (2001 onwards)
        relevant_data_points = [
            dp for dp in data_points if dp.startswith("20")
        ]  # Quickest check on the year if the data format stays the same

        # Group by word
        data_dict = {}
        for dp in relevant_data_points:
            try:
                year, count, books = map(int, dp.split(","))  # Unpack directly
                if year >= 2001:
                    if word not in data_dict:
                        data_dict[word] = [0, 0]
                    data_dict[word][0] += count
                    data_dict[word][1] += books
            except ValueError:
                # Handle cases where data is malformed
                continue

        # Calculate total count of occurrences and books (word may be present in another database as well, so this may need to be changed)
        for word, (total_count, total_books) in data_dict.items():
            data.append([word, total_count, total_books])

    return pd.DataFrame(data, columns=["word", "occurrence", "bookcount"])


def read_gzip_ngrams(filepath, chunksize=1000 * 2**20):  # chunksize is 1000MB
    """Reads a gzip file in chunks using Dask and processes each chunk."""
    dfs = []
    t0 = time.time()
    chunk_count = 0
    total_time = 0

    with gzip.open(filepath, "rt", encoding="utf-8") as f:
        while True:
            chunk = f.read(chunksize)
            if not chunk:
                break  # End of file
            t1 = time.time()
            total_time += t1 - t0
            chunk_count += 1
            sys.stdout.write(
                f"\rChunk {chunk_count}, Total Time: {total_time:.2f} seconds"
            )
            sys.stdout.flush()
            t0 = time.time()

            # Process the chunk using the function defined above
            df = process_chunk(chunk)
            dfs.append(df)

    # Concatenate all the pandas DataFrames into a single pandas DataFrame
    if dfs:
        df = pd.concat(dfs, ignore_index=True)
    else:
        df = pd.DataFrame(
            columns=["word", "occurrence", "bookcount"]
        )  # Empty DataFrame

    return df


folder_path = "./ngrams/"
filepaths = [
    os.path.join(folder_path, file)
    for file in os.listdir(folder_path)
    if file.endswith(".gz")
]

# Initialize an empty DataFrame to store the results
df = pd.DataFrame(columns=["word", "occurrence", "bookcount"])
total_time = 0
t0 = time.time()

for i, filepath in enumerate(filepaths):
    t1 = time.time()
    run_time = 0
    if not os.path.exists(filepath):
        sys.stdout.write(f"\rError: File not found - {filepath}\n")
        continue

    file_df = read_gzip_ngrams(filepath)
    df = pd.concat([df, file_df], ignore_index=True)

    t2 = time.time()
    total_time = t2 - t0
    run_time += t2 - t1
    sys.stdout.write(
        f"\rProcessed file {i + 1} of {len(filepaths)}: {filepath} in {run_time:.2f} seconds, Total Time: {total_time:.2f} seconds\n"
    )

print("\r")
print("df created. Checking for high frequency words...")

# We only want words that are present in at least x occurrences and in at least y books
threshold_count = 100000
threshold_books = 1000
df = df.groupby("word").agg({"occurrence": "sum", "bookcount": "sum"}).reset_index()
df = df[(df["occurrence"] > threshold_count) & (df["bookcount"] > threshold_books)]

print("df filtered. Writing to disk...")

df.to_csv("./ngrams/word_ngrams.csv", index=False)
print("df written to disk.")
