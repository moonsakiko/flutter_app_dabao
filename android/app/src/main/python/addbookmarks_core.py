import os
import re
import sys
from glob import glob
from pypdf import PdfReader, PdfWriter

def parse_toc_from_file(toc_filepath, page_offset):
    toc = []
    parent_stack = [toc]
    
    with open(toc_filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.rstrip()
            if not line.strip():
                continue
            
            level = 0
            while line.startswith('\t' * (level + 1)):
                level += 1
            
            match = re.search(r'([\s\t]+)(\d+)$', line)
            if match:
                title_end_pos = match.start(1)
                title = line[:title_end_pos].strip()
                page_num = int(match.group(2))
            else:
                print(f"   Warning (Line {line_num}): Cannot parse page number -> '{line}'")
                continue

            while len(parent_stack) > level + 1:
                parent_stack.pop()
            
            new_bookmark_list = []
            final_page_num = page_num + page_offset
            parent_stack[-1].append((title, final_page_num, new_bookmark_list))
            parent_stack.append(new_bookmark_list)
            
    return toc

def add_bookmarks_to_writer(writer, bookmarks_data, parent=None):
    for item in bookmarks_data:
        title, page_num, children = item
        # pypdf indexes from 0
        try:
             new_bookmark = writer.add_outline_item(title, page_num - 1, parent=parent)
             if children:
                 add_bookmarks_to_writer(writer, children, parent=new_bookmark)
        except Exception as e:
             print(f"Error adding bookmark '{title}': {e}")

def run(args):
    """
    args = {
        'source_folder': '/path',
        'offset': 0
    }
    """
    source_folder = args.get('source_folder')
    output_folder = args.get('output_folder') # Add this to args
    page_offset = int(args.get('offset', 0))
    
    if not source_folder:
        print("No source folder provided")
        return
        
    if not output_folder:
        # Default to a subfolder if not provided
        output_folder = os.path.join(source_folder, "output_with_bookmarks")
        
    os.makedirs(output_folder, exist_ok=True)
    
    pdf_files = sorted([f for f in os.listdir(source_folder) if f.lower().endswith('.pdf')])
    
    if not pdf_files:
        print("No PDF files found.")
        return

    for filename in pdf_files:
        pdf_path = os.path.join(source_folder, filename)
        base_name = os.path.splitext(filename)[0]
        toc_filename = base_name + '.txt'
        toc_path = os.path.join(source_folder, toc_filename)
        
        print(f"\n--- Processing: {filename} ---")
        
        if not os.path.isfile(toc_path):
            print(f"   Skipped: No TOC file '{toc_filename}' found.")
            continue
            
        try:
            toc_data = parse_toc_from_file(toc_path, page_offset)
            if not toc_data:
                print("   Warning: Empty or invalid TOC.")
                continue

            reader = PdfReader(pdf_path)
            writer = PdfWriter()
            writer.clone_document_from_reader(reader) # More efficient clone
            # clone_document_from_reader usually preserves existing pages but might not remove existing bookmarks if we don't clear them.
            # But here we are just adding new ones (or overlaying). 
            # If we want to replace, we'd iterate pages. 
            # The original script used loop page addition:
            # for page in reader.pages: writer.add_page(page)
            # Let's stick to the safer original loop method to strip old bookmarks implicitly if any.
            
            writer = PdfWriter() # Reinitalize empty
            for page in reader.pages:
                 writer.add_page(page)

            add_bookmarks_to_writer(writer, toc_data)
            
            out_file = os.path.join(output_folder, filename)
            with open(out_file, "wb") as f_out:
                writer.write(f_out)
            
            print(f"   Success! Saved to {os.path.basename(out_file)}")
            
        except Exception as e:
            print(f"   Error: {e}")
            traceback.print_exc()

    print("Done.")
