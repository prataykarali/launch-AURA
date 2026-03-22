from googletrans import Translator
import pdfplumber  # Library to read PDFs

def smart_search(file_path, search_term_english, target_lang='bn'):
    # Step 1: Translate the search term
    translator = Translator()
    # Translate English to Bengali ('bn')
    translated_term = translator.translate(search_term_english, dest=target_lang).text
    print(f"Searching for: {translated_term}...")

    # Step 2: Search the file
    matches = []
    with pdfplumber.open(file_path) as pdf:
        for page_num, page in enumerate(pdf.pages):
            text = page.extract_text()
            if text and translated_term in text:
                # Find specific lines containing the term
                for line in text.split('\n'):
                    if translated_term in line:
                        matches.append(f"Page {page_num + 1}: {line}")
    
    return matches