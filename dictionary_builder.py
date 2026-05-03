import pandas as pd
import requests
import time
import sys
import os
import json

API_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
AUDIO_FOLDER = "./dictionary_audio/"
CACHE_FOLDER = "./cache/"
SAVE_INTERVAL = 100


def download_audio(audio_url, word):
    if not audio_url:
        return None
    try:
        response = requests.get(audio_url, stream=True, timeout=10)
        response.raise_for_status()
        filename = os.path.join(AUDIO_FOLDER, f"{word}.mp3")
        with open(filename, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return filename
    except Exception as e:
        print(f"\nError downloading audio for {word}: {e}")
        return None


def get_word_details(word):
    try:
        response = requests.get(API_URL + word, timeout=10)
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

            # ---- FIXED + INSTRUMENTED PHONETICS ----
            has_audio_url = False

            for phonetic in word_data.get("phonetics", []):
                audio_url = phonetic.get("audio", "")

                if audio_url:
                    has_audio_url = True

                details["phonetics"].append({
                    "text": phonetic.get("text", ""),
                    "audio": audio_url,
                })

                # Only first valid audio (no overwrite bug)
                if audio_url and details["audio"] is None:
                    print(f"HAS AUDIO URL: {word} -> {audio_url}")

                    downloaded = download_audio(audio_url, word)

                    if downloaded:
                        print(f"DOWNLOADED: {word}")
                        details["audio"] = downloaded
                    else:
                        print(f"FAILED DOWNLOAD: {word}")

            # detect silent failure
            if has_audio_url and details["audio"] is None:
                print(f"AUDIO URL PRESENT BUT NONE SAVED: {word}")

            # meanings
            for meaning in word_data.get("meanings", []):
                meaning_details = {
                    "partOfSpeech": meaning.get("partOfSpeech", ""),
                    "definitions": [],
                    "synonyms": meaning.get("synonyms", []),
                    "antonyms": meaning.get("antonyms", []),
                }
                for definition in meaning.get("definitions", []):
                    meaning_details["definitions"].append({
                        "definition": definition.get("definition", ""),
                        "example": definition.get("example", ""),
                    })
                details["meanings"].append(meaning_details)

            for source_url in word_data.get("sourceUrls", []):
                details["sourceUrls"].append(source_url)

            return details

        return {"error": "No details found"}

    except Exception as e:
        return {"error": str(e)}


def main(num_iterations=200):
    df = pd.read_csv("./ngrams/word_ngrams.csv")
    df = df[df["word"].str.len().between(3, 12)].reset_index(drop=True)

    os.makedirs(AUDIO_FOLDER, exist_ok=True)
    os.makedirs(CACHE_FOLDER, exist_ok=True)

    word_details_list = []

    for _, row in df.head(num_iterations).iterrows():
        word = row["word"]
        details = get_word_details(word)

        if details.get("word"):
            word_details_list.append(details)

    # save output
    if word_details_list:
        out_df = pd.DataFrame(word_details_list)
        out_df.to_csv("./lexodle_details_debug.csv", index=False)
        print("\nSaved debug CSV")

    print("\nDone")


if __name__ == "__main__":
    main()