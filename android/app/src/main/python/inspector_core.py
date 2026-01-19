import os
import re
from pdfminer.high_level import extract_pages
from pdfminer.layout import LTTextContainer, LTTextLineHorizontal, LTChar

def is_garbage(text):
    # Simple garbage detection: short and no chinese
    if len(text) < 5:
        # Check if contains Chinese
        if not re.search(r'[\u4e00-\u9fff]', text):
            return True
    return False

def highlight_suspected_title(text, info):
    # Heuristic for title
    if info['size'] > 12: # Configurable?
        return f"『{text}』(Size:{info['size']})"
    return text

def run_inspector(args):
    """
    args = {
        'input_folder': '/path',
        'output_folder': '/path',
        'pages': [1, 2, 3] # Optional list of pages
    }
    """
    input_folder = args.get('input_folder')
    output_folder = args.get('output_folder')
    target_pages = args.get('pages', []) # List of 1-based page numbers
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    pdf_files = [f for f in os.listdir(input_folder) if f.lower().endswith('.pdf')]
    
    for filename in pdf_files:
        pdf_path = os.path.join(input_folder, filename)
        txt_path = os.path.join(output_folder, os.path.splitext(filename)[0] + '.txt')
        
        print(f"\nInspecting {filename}...")
        
        with open(txt_path, 'w', encoding='utf-8') as f:
            try:
                # convert pages to set for O(1) lookup, adjust for 0-index if needed
                target_pages_set = set(target_pages)
                
                for page_layout in extract_pages(pdf_path, page_numbers=None if not target_pages else [p-1 for p in target_pages]):
                    page_num = page_layout.pageid # 1-based usually in pdfminer
                    
                    f.write(f"\n{'='*20} Page {page_num} {'='*20}\n")
                    
                    for element in page_layout:
                        if isinstance(element, LTTextContainer):
                            for text_line in element:
                                if isinstance(text_line, LTTextLineHorizontal):
                                    text = text_line.get_text().strip()
                                    if not text: continue
                                    
                                    # Purification
                                    if is_garbage(text): continue
                                    
                                    # Get font info
                                    first_char = next((c for c in text_line if isinstance(c, LTChar)), None)
                                    font_name = first_char.fontname if first_char else "Unknown"
                                    font_size = round(first_char.size, 2) if first_char else 0
                                    
                                    x0 = round(text_line.x0, 2)
                                    y_top = round(page_layout.height - text_line.y1, 2)
                                    
                                    # Format output
                                    info_str = f"[Size:{font_size} | Font:{font_name} | Y:{y_top} | X:{x0}]"
                                    
                                    # Highlight
                                    display_text = text
                                    if font_size >= 14: # Simple heuristic
                                         display_text = f"『 {text} 』 <--- Suspected Title"
                                    
                                    f.write(f"{info_str} {display_text}\n")
                                    
                print(f"Report saved to {os.path.basename(txt_path)}")
            except Exception as e:
                print(f"Error inspecting {filename}: {e}")
                f.write(f"\nError: {e}")
