import os

allowed_files = [
    'glass_bottom_nav.dart',
    'integrated_bottom_shell.dart',
    'player_screen.dart',
    'playlist_selector_sheet.dart',
    'social_share_sheet.dart',
    'spotify_import_sheet.dart',
    'settings_screen.dart', # Keep some UI if deeply needed
]

def remove_backdrop_filter(content):
    # This is a basic bracket parser to strip "BackdropFilter( ... child: " 
    out = ""
    i = 0
    while i < len(content):
        # Look for BackdropFilter
        if content[i:].startswith('BackdropFilter('):
            # Parse until child:
            child_idx = content.find('child:', i)
            if child_idx != -1 and child_idx < i + 500: # ensure it's the same block
                # Skip to the value of child:
                i = child_idx + 6
                # Skip whitespace
                while content[i] in ' \n\r\t':
                    i += 1
                
                # Now we need to find the matching closing bracket for BackdropFilter
                # But wait! We are literally extracting the child out of the BackdropFilter!
                # Actually, the easier regex way for Flutter is replacing BackdropFilter(filter: ImageFilter.blur(...), child: X) with X.
                # However, bracket counting is safer.
                pass
        out += content[i]
        i += 1
    return out

# Actually, an easier way is to just use standard multi_replace_file_content by doing grep first and carefully replacing.
