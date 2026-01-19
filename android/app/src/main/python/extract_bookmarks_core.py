import os
from pypdf import PdfReader

def parse_outlines(outlines, reader, depth=0):
    bookmark_list = []
    i = 0
    while i < len(outlines):
        item = outlines[i]
        
        # Check if item is a Destination (list/dictionary)
        # In pypdf, Destination is a Dictionary-like object
        # If it is a list, it's a sub-list of bookmarks (but usually PyPDF2 structure is flat list with nesting implied or explicit)
        # The provided logic in markdown was specific to PyPDF2 structure which interleaves lists.
        # pypdf (newer) also follows similar structure where nested items are in a list following the parent.
        
        if isinstance(item, list):
            # This is a sub-list (children of previous item)
            # But the recursive call below usually handles it.
            # If we hit a list directly here, it means we are recursing.
            # Wait, the markdown logic handled: current=dict, next=list.
            # Let's trust the logic from markdown which was debugged for this.
            pass
        
        # Checking if it's a bookmark item
        try:
            # In pypdf, item might be Destination or a list
            if isinstance(item, list):
               # Recursive call for children if we encounter a raw list (sometimes happens?)
               # But standard structure is [Dest, [Dest, Dest], Dest]
               child_bookmarks = parse_outlines(item, reader, depth + 1)
               bookmark_list.extend(child_bookmarks)
               i += 1
               continue
               
            title = item.get('/Title', 'Untitled')
            page_obj = item.get('/Page')
            page_num = -1
            if page_obj:
               try:
                   page_num = reader.get_page_number(page_obj) + 1
               except:
                   page_num = "?"
            
            indent = "\t" * depth
            bookmark_list.append(f"{indent}{title}\t{page_num}")
            
            # Check for children (modern pypdf usually has children in '/First', '/Last' etc if it's a tree,
            # BUT raw outline property often returns the list-interleaved format)
            # We implemented the 'look ahead' logic in markdown.
            
            # Look ahead for children list
            if i + 1 < len(outlines) and isinstance(outlines[i+1], list):
                 child_bookmarks = parse_outlines(outlines[i+1], reader, depth + 1)
                 bookmark_list.extend(child_bookmarks)
                 i += 2 # Skip current and the list
            else:
                 i += 1
                 
        except Exception:
            # Not a standard bookmark item, skip
            i += 1
            
    return bookmark_list

def run_extract(args):
    input_folder = args.get('input_folder')
    output_folder = args.get('output_folder')
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    pdf_files = [f for f in os.listdir(input_folder) if f.lower().endswith('.pdf')]
    
    for filename in pdf_files:
        pdf_path = os.path.join(input_folder, filename)
        txt_path = os.path.join(output_folder, os.path.splitext(filename)[0] + '.txt')
        
        print(f"Extracting {filename}...")
        try:
            reader = PdfReader(pdf_path)
            if reader.outline:
                 bookmarks = parse_outlines(reader.outline, reader)
                 if bookmarks:
                     with open(txt_path, 'w', encoding='utf-8') as f:
                         f.write("\n".join(bookmarks))
                     print(f"Saved to {os.path.basename(txt_path)}")
                 else:
                     print("No bookmarks extracted.")
            else:
                 print("No outline found.")
                 
        except Exception as e:
            print(f"Error parsing {filename}: {e}")
