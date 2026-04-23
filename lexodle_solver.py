import os
import platform
import pandas as pd


def clear_terminal():
    """Clears the terminal screen."""
    system = platform.system()
    if system == "Windows":
        os.system("cls")
    elif system in ("Linux", "Darwin"):  # Linux or macOS
        os.system("clear")
    else:
        print(f"Unsupported operating system: {system}. Cannot clear terminal.")


# Clear the terminal before running the rest of the code
clear_terminal()


def filter_words_by_absent_letters(filepath, absent_letters):
    """
    Filters a list of words from a CSV file, excluding words that contain
    specified letters.

    Args:
        filepath (str): The path to the CSV file containing the word list.
        absent_letters (str): A string containing the letters that should not
                              be present in the filtered words.

    Returns:
        list: A list of words that do not contain any of the specified absent
              letters. Returns an empty list if the file is not found or if
              there's an error.
    """
    try:
        # Read the CSV file into a pandas DataFrame
        df = pd.read_csv(filepath)

        # Check if the 'word' column exists
        if "word" not in df.columns:
            print(f"Error: 'word' column not found in {filepath}")
            return []

        # Convert absent_letters to lowercase for case-insensitive comparison
        absent_letters = absent_letters.lower()

        # Filter words that do not contain any of the absent letters
        filtered_words = []
        for word in df["word"]:
            word_lower = word.lower()
            valid = True
            for letter in absent_letters:
                if letter in word_lower:
                    valid = False
                    break
            if valid:
                filtered_words.append(word)

        return filtered_words

    except FileNotFoundError:
        print(f"Error: File not found at {filepath}")
        return []
    except pd.errors.EmptyDataError:
        print(f"Error: The file {filepath} is empty.")
        return []
    except pd.errors.ParserError:
        print(f"Error: Could not parse {filepath}. Please check the file format.")
        return []
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return []


def filter_words_by_present_letters_and_positions(
    word_list, present_letters, letter_positions="-----"
):
    """
    Filters a list of words from a CSV file based on the presence of specific
    letters and their positions.

    Args:
        filepath (str): The path to the CSV file containing the word list.
        present_letters (str): A string containing the letters that MUST be
                               present in the filtered words.
        letter_positions (str): A string representing the required letter
                                positions. Use '_' to represent unknown
                                positions. For example, "__e__" means 'e'
                                must be in the third position. The length of
                                this string should match the word length.

    Returns:
        list: A list of words that meet the specified criteria. Returns an
              empty list if the file is not found or if there's an error.
    """
    try:
        # Convert inputs to lowercase for case-insensitive comparison
        present_letters = present_letters.lower()
        letter_positions = letter_positions.lower()

        word_length = len(letter_positions)

        # Validate the entries
        if len(present_letters) > word_length:
            print(
                f"Error: present_letters cannot be longer than {word_length} chars as defined by letter_positions. Returning word_list."
            )
            return word_list
        elif not all(c.isalpha() or c == "-" for c in letter_positions):
            print(
                f"Error: Invalid characters in letter_positions. Only letters and '_' are allowed. Returning word_list."
            )
            return word_list
        elif len(present_letters) == 0:
            print("No present letters specified. Returning word_list.")
            return word_list

        # Filter words
        filtered_words = []
        for word in word_list:
            word_lower = word.lower()

            # Check word length
            if len(word_lower) != word_length:
                continue

            # Check for present letters
            all_present = True

            for letter in present_letters:
                if letter not in word_lower:
                    all_present = False
                    break
            if not all_present:
                continue

            # Check letter positions
            position_match = True
            for i, char in enumerate(letter_positions):
                if char != "-":
                    if word_lower[i] != char:
                        position_match = False
                        break
            if not position_match:
                continue

            filtered_words.append(word)

        return filtered_words

    except Exception as e:
        print(f"An unexpected error occurred: {e}. Returning word_list.")
        return word_list


# Example usage:
filepath = "./lexodle_list_5.csv"
# caret bingo dumps xylem wharf
absent_letters = "rtbhsp"
present_letters = "cae"  # jkqvz
letter_positions = "-c---"
# positioning asst '12345'

filtered_words = filter_words_by_absent_letters(filepath, absent_letters)
filtered_words2 = filter_words_by_present_letters_and_positions(
    filtered_words, present_letters, letter_positions
)


if filtered_words2:
    print(
        f"Words without the letters '{absent_letters}' & with the letters '{present_letters}'. Positions: '{letter_positions}':"
    )
    print(f"Total words found: {len(filtered_words2)}")
    for word in filtered_words2[:5]:
        print(word)
else:
    print("No words found matching the criteria.")
