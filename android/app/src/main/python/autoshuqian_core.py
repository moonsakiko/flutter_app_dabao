import os
import re
from pdfminer.high_level import extract_pages
from pdfminer.layout import LTTextContainer, LTTextLineHorizontal, LTChar
from pypdf import PdfReader, PdfWriter

def clean_and_truncate_title(text, config):
    ex_conf = config.get('exclusion', {})
    truncate_chars = ex_conf.get('truncate_chars', [])
    truncate_len = ex_conf.get('truncate_after_len', 10)
    for char in truncate_chars:
        if char in text:
            parts = text.split(char, 1)
            head, tail = parts[0], parts[1]
            if len(tail) > truncate_len:
                return head.strip()
    return text

def check_title_match(line_info, config):
    text = line_info['text']
    ex_conf = config.get('exclusion', {})
    
    if len(text) > ex_conf.get('max_line_length', 999): return None
    if any(char in text for char in ex_conf.get('exclude_chars', [])): return None
    
    y_from_top = line_info['y_from_top']
    if y_from_top < ex_conf.get('min_y_coord', 0): return None
    if y_from_top > ex_conf.get('max_y_coord', 9999): return None

    # Sort keys to ensure we check level1, level2 in order if possible, 
    # though dictionary order isn't guaranteed in older python, typical usage is fine.
    # We'll filter for keys starting with 'level'
    level_keys = [k for k in config.keys() if k.startswith('level')]
    # Simple sort to ensure level1 comes before level2
    level_keys.sort()

    for level_name in level_keys:
        rules = config[level_name]
        level = int(level_name.replace('level', ''))
        
        # Regex check
        regex_pattern = rules.get('regex')
        match_regex = True
        if regex_pattern:
            if not re.match(regex_pattern, text):
                match_regex = False
        
        # Font check
        match_font = True
        font_contains = rules.get('font_contains')
        if font_contains:
            if not any(f.lower() in line_info['font'].lower() for f in font_contains):
                match_font = False

        # Size check
        font_size_rule = rules.get('font_size', 0)
        match_size = False
        if isinstance(font_size_rule, (list, tuple)) and len(font_size_rule) == 2:
            target, tolerance = font_size_rule[0], font_size_rule[1]
            if (target - tolerance) <= line_info['size'] <= (target + tolerance):
                match_size = True
        elif isinstance(font_size_rule, (int, float)) and font_size_rule > 0:
            if line_info['size'] >= font_size_rule:
                match_size = True
        else:
            match_size = True

        # Indent check
        indent_rule = rules.get('indent_range')
        match_indent = False
        if isinstance(indent_rule, (list, tuple)) and len(indent_rule) == 2:
            if indent_rule[0] <= line_info['x0'] <= indent_rule[1]:
                match_indent = True
        elif indent_rule is None:
            match_indent = True
            
        if match_regex and match_font and match_size and match_indent:
            cleaned_text = clean_and_truncate_title(text, config)
            return [level, cleaned_text, line_info['page_num']]
            
    return None

def process_pdf(input_path, output_path, config):
    print(f"\n--- Processing: {os.path.basename(input_path)} ---")
    all_potential_titles = []

    try:
        print("  Step 1/3: Scanning pages...")
        for page_layout in extract_pages(input_path):
            page_height = page_layout.height
            for element in page_layout:
                if isinstance(element, LTTextContainer):
                    for text_line in element:
                        if isinstance(text_line, LTTextLineHorizontal):
                            line_text = text_line.get_text().strip()
                            if not line_text: continue
                            
                            first_char = next((c for c in text_line if isinstance(c, LTChar)), None)
                            if not first_char: continue

                            line_info = {
                                'text': line_text, 'font': first_char.fontname,
                                'size': round(first_char.size), 'x0': text_line.x0,
                                'y1': text_line.y1, 'page_num': page_layout.pageid - 1,
                                'page_height': page_height, 'y_from_top': page_height - text_line.y1
                            }

                            match = check_title_match(line_info, config)
                            if match:
                                print(f"    > Page {match[2] + 1}: Found '{match[1]}'")
                                all_potential_titles.append({
                                    "level": match[0], "title": match[1],
                                    "page_num": match[2], "y": line_info['y_from_top']
                                })
    except Exception as e:
        print(f"!!! Error scanning '{os.path.basename(input_path)}': {e}")
        return

    if not all_potential_titles:
        print(f"  Warning: No titles found in '{os.path.basename(input_path)}'.")
        # Copy file even if no bookmarks found? Yes, to keep output consistent
        try:
             import shutil
             shutil.copy(input_path, output_path)
             print("  Copied original file to output.")
        except:
             pass
        return

    print("  Step 2/3: Sorting titles...")
    toc = sorted(all_potential_titles, key=lambda x: (x['page_num'], x['y']))

    print(f"  Step 3/3: Generating {len(toc)} bookmarks...")
    try:
        reader = PdfReader(input_path)
        writer = PdfWriter()
        writer.clone_document_from_reader(reader)

        last_toc_at_level = [None] * 10
        for item in toc:
            level, title, page_num = item['level'], item['title'], item['page_num']
            # Safety check for levels
            if level < 1: level = 1
            
            parent = last_toc_at_level[level - 2] if level > 1 else None
            # Need to handle if parent is None but level > 1 (broken hierarchy)
            # If parent is None and level > 1, maybe attach to root or nearest upper level? 
            # For now, PyPDF handles parent=None as root.
            
            new_bookmark = writer.add_outline_item(title, page_num, parent=parent)
            last_toc_at_level[level - 1] = new_bookmark
            for i in range(level, len(last_toc_at_level)):
                last_toc_at_level[i] = None

        with open(output_path, "wb") as f:
            writer.write(f)
        print(f"  Saved to: {os.path.basename(output_path)}")

    except Exception as e:
        print(f"!!! Error writing '{os.path.basename(output_path)}': {e}")


def run(args):
    """
    args = {
        'input_folder': '/path/to/in',
        'output_folder': '/path/to/out',
        'config': { ... }
    }
    """
    input_folder = args.get('input_folder')
    output_folder = args.get('output_folder')
    config = args.get('config', {})
    
    if not input_folder or not output_folder:
        print("Missing input or output folder")
        return

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    pdf_files = [f for f in os.listdir(input_folder) if f.lower().endswith('.pdf')]
    print(f"Found {len(pdf_files)} PDF files in {input_folder}")
    
    for filename in pdf_files:
        in_path = os.path.join(input_folder, filename)
        out_path = os.path.join(output_folder, filename)
        process_pdf(in_path, out_path, config)
    
    print("All tasks completed.")
