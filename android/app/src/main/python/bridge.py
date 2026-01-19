import sys
import io
import os
import json
import traceback
from os.path import dirname, join

# Import our tool scripts
# We will create these next
try:
    import autoshuqian_core
    import addbookmarks_core
    import inspector_core
    import extract_bookmarks_core
except ImportError:
    pass # Will be handled when running

def run_script(script_name, args_json):
    """
    Generic entry point for Flutter to call Python.
    script_name: 'auto_shuqian', 'add_bookmarks', 'inspector', 'extract'
    args_json: JSON string containing parameters
    """
    
    # Redirect stdout/stderr to capture logs
    log_capture = io.StringIO()
    original_stdout = sys.stdout
    original_stderr = sys.stderr
    sys.stdout = log_capture
    sys.stderr = log_capture

    result = {
        "success": False,
        "message": "",
        "logs": "",
        "data": None
    }

    try:
        args = json.loads(args_json)
        print(f"--- Python: Starting {script_name} ---")
        
        if script_name == 'auto_shuqian':
            # args: input_folder, output_folder, config
            autoshuqian_core.run(args)
        elif script_name == 'add_bookmarks':
            # args: source_folder, offset
            # addbookmarks.py usually scans a folder. We can adapt it.
            addbookmarks_core.run(args)
        elif script_name == 'inspector':
            # args: input_folder, output_folder, pages
            inspector_core.run_inspector(args)
        elif script_name == 'extract':
             # args: input_folder, output_folder
            extract_bookmarks_core.run_extract(args)
        else:
            print(f"Unknown script: {script_name}")
            raise ValueError(f"Unknown script: {script_name}")

        result["success"] = True
        result["message"] = "Execution completed successfully"

    except Exception as e:
        traceback.print_exc()
        result["message"] = str(e)
    
    finally:
        # Restore stdout
        sys.stdout = original_stdout
        sys.stderr = original_stderr
        result["logs"] = log_capture.getvalue()
    
    return json.dumps(result)
