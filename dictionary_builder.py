import pandas as pd
import requests
import time
import sys
import os

API_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
AUDIO_FOLDER = "./dictionary_audio/"  # Folder to save audio files
SAVE_INTERVAL = 1000  # Save the CSV every 1000 words


def download_audio(audio_url, word):
    """Downloads an audio file from a URL and saves it."""
    if not audio_url:
        return None
    try:
        response = requests.get(audio_url, stream=True)
        response.raise_for_status()
        filename = os.path.join(AUDIO_FOLDER, f"{word}.mp3")
        with open(filename, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return filename
    except requests.exceptions.RequestException as e:
        print(f"Error downloading audio for {word}: {e}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred while downloading audio for {word}: {e}")
        return None


def get_word_details(word):
    """
    Fetches detailed information about a word from the Dictionary API.

    Args:
        word (str): The word to look up.

    Returns:
        dict: A dictionary containing the word's details, or an error message.
    """
    try:
        response = requests.get(API_URL + word)
        response.raise_for_status()

        data = response.json()
        if isinstance(data, list) and len(data) > 0:
            word_data = data[0]
            details = {
                "word": word,
                "phonetics": [],
                "meanings": [],
                "sourceUrls": [],
                "audio": None,
            }

            # Extract phonetics
            for phonetic in word_data.get("phonetics", []):
                details["phonetics"].append(
                    {
                        "text": phonetic.get("text", ""),
                        "audio": phonetic.get("audio", ""),
                    }
                )
                if phonetic.get("audio", ""):
                    details["audio"] = download_audio(phonetic.get("audio", ""), word)

            # Extract meanings
            for meaning in word_data.get("meanings", []):
                meaning_details = {
                    "partOfSpeech": meaning.get("partOfSpeech", ""),
                    "definitions": [],
                    "synonyms": meaning.get("synonyms", []),
                    "antonyms": meaning.get("antonyms", []),
                }
                for definition in meaning.get("definitions", []):
                    meaning_details["definitions"].append(
                        {
                            "definition": definition.get("definition", ""),
                            "example": definition.get("example", ""),
                        }
                    )
                details["meanings"].append(meaning_details)

            # Extract source URLs
            for source_url in word_data.get("sourceUrls", []):
                details["sourceUrls"].append(source_url)

            return details
        else:
            return {"error": "No details found for the word."}
    except requests.exceptions.HTTPError as http_err:
        if response.status_code == 404:
            return {"error": "Word not found."}
        else:
            return {"error": f"HTTP error occurred: {http_err}"}
    except requests.exceptions.RequestException as req_err:
        return {"error": f"Request error occurred: {req_err}"}
    except Exception as err:
        return {"error": f"An error occurred: {err}"}


def save_intermediate_results(word_details_df, filepath):
    """Saves the current DataFrame to a CSV file."""
    try:
        word_details_df.to_csv(filepath, index=False)
        print(f"\nIntermediate data saved to {filepath}")
    except Exception as e:
        print(f"\nAn error occurred while saving the intermediate data: {e}")


def main(num_iterations=None):
    """
    Reads a CSV of words, looks up their details, and saves the results to a new CSV.
    Saves intermediate results at regular intervals.
    """
    try:
        word_usage_df = pd.read_csv("./ngrams/word_ngrams.csv")
    except FileNotFoundError:
        print(
            "Error: word_ngrams.csv not found. Please ensure the file exists in the correct directory."
        )
        return
    except pd.errors.EmptyDataError:
        print("Error: word_ngrams.csv is empty.")
        return
    except pd.errors.ParserError:
        print("Error: Could not parse word_ngrams.csv. Please check the file format.")
        return
    except Exception as e:
        print(f"An unexpected error occurred while reading word_ngrams.csv: {e}")
        return

    word_usage_df = word_usage_df[word_usage_df["word"].str.len() == 5]
    word_usage_df = word_usage_df.reset_index(drop=True)

    # Create the audio folder if it doesn't exist
    os.makedirs(AUDIO_FOLDER, exist_ok=True)

    word_details_list = []
    total_words = len(word_usage_df)
    start_time = time.time()

    # Determine the number of iterations
    if num_iterations is None or num_iterations > total_words:
        num_iterations = total_words

    intermediate_save_counter = 0
    for index, row in word_usage_df.head(
        num_iterations
    ).iterrows():  # only iterate over the first num_iterations rows
        word = row["word"]
        details = get_word_details(word)
        word_details_list.append(details)

        elapsed_time = time.time() - start_time
        words_processed = index + 1
        words_left = num_iterations - words_processed
        estimated_time_left = (
            (elapsed_time / words_processed) * words_left if words_processed > 0 else 0
        )

        sys.stdout.write(
            f"\rProcessed {word}: {words_processed}/{num_iterations} words. Estimated time left: {estimated_time_left:.2f} seconds"
        )
        sys.stdout.flush()
        time.sleep(0.1)

        # Save intermediate results
        if words_processed % SAVE_INTERVAL == 0:
            intermediate_save_counter += 1
            # Convert the list of dictionaries to a DataFrame
            word_details_df = pd.DataFrame(word_details_list)
            word_usage_df.rename(
                columns={"occurrence": "wordcount", "bookcount": "bookcount"},
                inplace=True,
            )
            word_details_df = pd.concat(
                [word_usage_df.head(words_processed), word_details_df], axis=1
            )
            save_intermediate_results(
                word_details_df,
                f"./lexodle_details_intermediate_{intermediate_save_counter}.csv",
            )
            # word_details_list = [] # reset the list

    # Save the final results (if there are any remaining words)
    if word_details_list:
        word_details_df = pd.DataFrame(word_details_list)
        word_usage_df.rename(
            columns={"occurrence": "wordcount", "bookcount": "bookcount"}, inplace=True
        )
        word_details_df = pd.concat(
            [word_usage_df.head(words_processed), word_details_df], axis=1
        )
        try:
            word_details_df.to_csv("./lexodle_details.csv", index=False)
            print(f"\nData saved to ./lexodle_details.csv")
        except Exception as e:
            print(f"\nAn error occurred while saving the data: {e}")


if __name__ == "__main__":
    # main(num_iterations=100)
    # To process all words, use:
    main()
